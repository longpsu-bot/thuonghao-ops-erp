-- PANTRY-NG-02: direct Pantry contribution persistence and materialization.
--
-- This forward-only migration extends the existing Need Generation evidence
-- model. It creates no new relation, API, function, role, capability, policy,
-- grant, or trigger.

alter table atlas_planning.need_generation_input_snapshots
  add column pantry_need_batch_id uuid,
  add column pantry_need_batch_version bigint,
  add column pantry_need_approval_snapshot_id uuid,
  add constraint need_generation_input_snapshots_pantry_binding_check check (
    (
      pantry_need_batch_id is null
      and pantry_need_batch_version is null
      and pantry_need_approval_snapshot_id is null
    )
    or (
      pantry_need_batch_id is not null
      and pantry_need_batch_version is not null
      and pantry_need_batch_version > 0
      and pantry_need_approval_snapshot_id is not null
    )
  ),
  add constraint need_generation_input_snapshots_pantry_snapshot_fkey
    foreign key (
      pantry_need_approval_snapshot_id,
      pantry_need_batch_id,
      pantry_need_batch_version
    )
    references atlas_planning.pantry_need_approval_snapshots (
      pantry_need_approval_snapshot_id,
      pantry_need_batch_id,
      approved_batch_version
    )
    on delete restrict;

create index need_generation_input_snapshots_pantry_snapshot_idx
  on atlas_planning.need_generation_input_snapshots (
    pantry_need_approval_snapshot_id,
    pantry_need_batch_id,
    pantry_need_batch_version
  )
  where pantry_need_approval_snapshot_id is not null;

alter table atlas_planning.theoretical_need_lines
  add column contribution_family text not null default 'RECIPE_DERIVED',
  add column delivery_location_id uuid,
  add column pantry_need_batch_id uuid,
  add column pantry_need_batch_version bigint,
  add column pantry_need_approval_snapshot_id uuid,
  add column pantry_need_line_id uuid,
  add column pantry_active_snapshot_member_line_id uuid;

alter table atlas_planning.theoretical_need_lines
  alter column need_generation_recipe_selection_id drop not null,
  alter column need_generation_recipe_line_use_id drop not null,
  alter column weekly_menu_approval_snapshot_line_id drop not null,
  alter column weekly_menu_approval_snapshot_id drop not null,
  alter column weekly_menu_id drop not null,
  alter column weekly_menu_version drop not null,
  alter column weekly_menu_line_id drop not null,
  alter column attendance_approval_snapshot_line_id drop not null,
  alter column attendance_approval_snapshot_id drop not null,
  alter column attendance_batch_id drop not null,
  alter column attendance_version drop not null,
  alter column attendance_line_id drop not null,
  alter column dish_id drop not null,
  alter column recipe_id drop not null,
  alter column recipe_version_id drop not null,
  alter column recipe_line_id drop not null,
  alter column recipe_line_revision_id drop not null,
  alter column need_generation_calculation_contract_id drop not null,
  alter column need_generation_calculation_contract_revision_id drop not null,
  alter column calculation_contract_revision_number drop not null;

alter table atlas_planning.theoretical_need_lines
  drop constraint theoretical_need_lines_atomic_anchor_key,
  drop constraint theoretical_need_lines_quantity_disposition_check,
  add constraint theoretical_need_lines_contribution_family_check check (
    contribution_family in ('RECIPE_DERIVED', 'PANTRY_DIRECT')
  ),
  add constraint theoretical_need_lines_source_family_check check (
    (
      contribution_family = 'RECIPE_DERIVED'
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
      contribution_family = 'PANTRY_DIRECT'
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
  ),
  add constraint theoretical_need_lines_quantity_disposition_check check (
    (
      line_disposition = 'ACTIVE'
      and (
        (contribution_family = 'RECIPE_DERIVED' and theoretical_quantity >= 0)
        or (contribution_family = 'PANTRY_DIRECT' and theoretical_quantity > 0)
      )
    )
    or (
      line_disposition = 'REMOVED'
      and theoretical_quantity = 0
      and predecessor_need_generation_run_id is not null
      and predecessor_theoretical_need_line_id is not null
    )
  ),
  add constraint theoretical_need_lines_delivery_location_fkey
    foreign key (delivery_location_id)
    references atlas_admin.delivery_locations (delivery_location_id)
    on delete restrict,
  add constraint theoretical_need_lines_pantry_snapshot_fkey
    foreign key (
      pantry_need_approval_snapshot_id,
      pantry_need_batch_id,
      pantry_need_batch_version
    )
    references atlas_planning.pantry_need_approval_snapshots (
      pantry_need_approval_snapshot_id,
      pantry_need_batch_id,
      approved_batch_version
    )
    on delete restrict,
  add constraint theoretical_need_lines_pantry_line_fkey
    foreign key (pantry_need_line_id, pantry_need_batch_id)
    references atlas_planning.pantry_need_lines (
      pantry_need_line_id,
      pantry_need_batch_id
    )
    on delete restrict,
  add constraint theoretical_need_lines_pantry_active_member_fkey
    foreign key (
      pantry_need_approval_snapshot_id,
      pantry_active_snapshot_member_line_id
    )
    references atlas_planning.pantry_need_approval_snapshot_lines (
      pantry_need_approval_snapshot_id,
      pantry_need_line_id
    )
    on delete restrict;

create unique index theoretical_need_lines_recipe_atomic_anchor_key
  on atlas_planning.theoretical_need_lines (
    need_generation_run_id,
    weekly_menu_approval_snapshot_line_id,
    attendance_approval_snapshot_line_id,
    recipe_line_revision_id,
    need_generation_calculation_contract_revision_id
  )
  where contribution_family = 'RECIPE_DERIVED';

create unique index theoretical_need_lines_pantry_active_anchor_key
  on atlas_planning.theoretical_need_lines (
    need_generation_run_id,
    pantry_need_approval_snapshot_id,
    pantry_active_snapshot_member_line_id
  )
  where contribution_family = 'PANTRY_DIRECT'
    and line_disposition = 'ACTIVE';

create unique index theoretical_need_lines_pantry_removed_anchor_key
  on atlas_planning.theoretical_need_lines (
    need_generation_run_id,
    pantry_need_approval_snapshot_id,
    pantry_need_line_id
  )
  where contribution_family = 'PANTRY_DIRECT'
    and line_disposition = 'REMOVED';

create index theoretical_need_lines_delivery_location_idx
  on atlas_planning.theoretical_need_lines (delivery_location_id)
  where delivery_location_id is not null;

create index theoretical_need_lines_pantry_snapshot_idx
  on atlas_planning.theoretical_need_lines (
    pantry_need_approval_snapshot_id,
    pantry_need_batch_id,
    pantry_need_batch_version
  )
  where pantry_need_approval_snapshot_id is not null;

create index theoretical_need_lines_pantry_line_idx
  on atlas_planning.theoretical_need_lines (
    pantry_need_line_id,
    pantry_need_batch_id
  )
  where pantry_need_line_id is not null;

create index theoretical_need_lines_pantry_active_member_idx
  on atlas_planning.theoretical_need_lines (
    pantry_need_approval_snapshot_id,
    pantry_active_snapshot_member_line_id
  )
  where pantry_active_snapshot_member_line_id is not null;

alter table atlas_planning.need_generation_issues
  add column pantry_need_approval_snapshot_id uuid,
  add column pantry_need_line_id uuid,
  add column pantry_active_snapshot_member_line_id uuid;

alter table atlas_planning.need_generation_issues
  drop constraint need_generation_issues_context_key,
  drop constraint need_generation_issues_code_check,
  add constraint need_generation_issues_pantry_context_check check (
    (
      pantry_need_approval_snapshot_id is null
      and pantry_need_line_id is null
      and pantry_active_snapshot_member_line_id is null
    )
    or (
      pantry_need_approval_snapshot_id is not null
      and pantry_need_line_id is not null
      and (
        pantry_active_snapshot_member_line_id is null
        or pantry_active_snapshot_member_line_id = pantry_need_line_id
      )
    )
  ),
  add constraint need_generation_issues_pantry_snapshot_fkey
    foreign key (pantry_need_approval_snapshot_id)
    references atlas_planning.pantry_need_approval_snapshots (
      pantry_need_approval_snapshot_id
    )
    on delete restrict,
  add constraint need_generation_issues_pantry_line_fkey
    foreign key (pantry_need_line_id)
    references atlas_planning.pantry_need_lines (pantry_need_line_id)
    on delete restrict,
  add constraint need_generation_issues_pantry_active_member_fkey
    foreign key (
      pantry_need_approval_snapshot_id,
      pantry_active_snapshot_member_line_id
    )
    references atlas_planning.pantry_need_approval_snapshot_lines (
      pantry_need_approval_snapshot_id,
      pantry_need_line_id
    )
    on delete restrict,
  add constraint need_generation_issues_context_key unique nulls not distinct (
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
    unit_id,
    pantry_need_approval_snapshot_id,
    pantry_need_line_id,
    pantry_active_snapshot_member_line_id
  ),
  add constraint need_generation_issues_code_check check (
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
      'RELEASE_ISSUE_SUMMARY_MISMATCH',
      'MISSING_PANTRY_INPUT_BINDING',
      'INVALID_PANTRY_SNAPSHOT_MEMBERSHIP',
      'PANTRY_APPROVED_QUANTITY_UNIT_MISMATCH'
    )
  );

create index need_generation_issues_pantry_snapshot_idx
  on atlas_planning.need_generation_issues (pantry_need_approval_snapshot_id)
  where pantry_need_approval_snapshot_id is not null;

create index need_generation_issues_pantry_line_idx
  on atlas_planning.need_generation_issues (pantry_need_line_id)
  where pantry_need_line_id is not null;

create index need_generation_issues_pantry_active_member_idx
  on atlas_planning.need_generation_issues (
    pantry_need_approval_snapshot_id,
    pantry_active_snapshot_member_line_id
  )
  where pantry_active_snapshot_member_line_id is not null;
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
    or row(
      v_snapshot.pantry_need_batch_id,
      v_snapshot.pantry_need_batch_version,
      v_snapshot.pantry_need_approval_snapshot_id
    ) is distinct from row(
      v_evaluation.pantry_need_batch_id,
      v_evaluation.pantry_need_batch_version,
      v_evaluation.pantry_need_approval_snapshot_id
    )
    or (
      (v_initial_check or (tg_table_name = 'need_generation_input_snapshots' and tg_op = 'INSERT'))
      and (
        v_snapshot.pantry_need_batch_id is null
        or v_snapshot.pantry_need_batch_version is null
        or v_snapshot.pantry_need_approval_snapshot_id is null
      )
    )
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
      or v_evaluation.pantry_need_batch_id is null
      or v_evaluation.pantry_need_batch_version is null
      or v_evaluation.pantry_need_approval_snapshot_id is null
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
      or not exists (
        select 1
        from atlas_planning.pantry_need_batches as pantry
        join atlas_planning.pantry_need_approval_snapshots as pantry_snapshot
          on pantry_snapshot.pantry_need_approval_snapshot_id = v_evaluation.pantry_need_approval_snapshot_id
         and pantry_snapshot.pantry_need_batch_id = pantry.pantry_need_batch_id
         and pantry_snapshot.approved_batch_version = pantry.version
        where pantry.pantry_need_batch_id = v_evaluation.pantry_need_batch_id
          and pantry.version = v_evaluation.pantry_need_batch_version
          and pantry.latest_approval_snapshot_id = v_evaluation.pantry_need_approval_snapshot_id
          and pantry.pantry_need_batch_status = 'APPROVED'
          and pantry.week_start <= v_run.period_start
          and pantry.week_end >= v_run.period_end
          and pantry_snapshot.line_count = (
            select count(*)
            from atlas_planning.pantry_need_approval_snapshot_lines as pantry_member
            where pantry_member.pantry_need_approval_snapshot_id = pantry_snapshot.pantry_need_approval_snapshot_id
          )
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
    from atlas_planning.theoretical_need_lines as pantry_line
    left join atlas_planning.pantry_need_approval_snapshot_lines as pantry_member
      on pantry_member.pantry_need_approval_snapshot_id = pantry_line.pantry_need_approval_snapshot_id
     and pantry_member.pantry_need_line_id = pantry_line.pantry_active_snapshot_member_line_id
    where pantry_line.need_generation_run_id = v_run.need_generation_run_id
      and pantry_line.contribution_family = 'PANTRY_DIRECT'
      and (
        pantry_line.need_generation_input_snapshot_id <> v_run.input_snapshot_id
        or row(
          pantry_line.pantry_need_batch_id,
          pantry_line.pantry_need_batch_version,
          pantry_line.pantry_need_approval_snapshot_id
        ) is distinct from row(
          v_snapshot.pantry_need_batch_id,
          v_snapshot.pantry_need_batch_version,
          v_snapshot.pantry_need_approval_snapshot_id
        )
        or pantry_line.service_date not between v_run.period_start and v_run.period_end
        or (
          pantry_line.line_disposition = 'ACTIVE'
          and (
            pantry_member.pantry_need_line_id is null
            or pantry_line.pantry_need_line_id <> pantry_member.pantry_need_line_id
            or pantry_line.school_id <> pantry_member.school_id
            or pantry_line.delivery_location_id <> pantry_member.delivery_location_id
            or pantry_line.service_date <> pantry_member.service_date
            or pantry_line.ingredient_id <> pantry_member.ingredient_id
            or pantry_line.unit_id <> pantry_member.unit_id
            or pantry_line.theoretical_quantity <> pantry_member.requested_quantity::numeric(20, 6)
          )
        )
        or (
          pantry_line.line_disposition = 'REMOVED'
          and (pantry_line.pantry_active_snapshot_member_line_id is not null or pantry_line.theoretical_quantity <> 0)
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Pantry contributions require exact approved membership, facts, quantity, Unit, and period';
  end if;

  if exists (
    select 1
    from atlas_planning.pantry_need_approval_snapshot_lines as pantry_member
    where pantry_member.pantry_need_approval_snapshot_id = v_snapshot.pantry_need_approval_snapshot_id
      and pantry_member.service_date between v_run.period_start and v_run.period_end
      and pantry_member.requested_quantity > 0
      and (
        select count(*)
        from atlas_planning.theoretical_need_lines as pantry_line
        where pantry_line.need_generation_run_id = v_run.need_generation_run_id
          and pantry_line.contribution_family = 'PANTRY_DIRECT'
          and pantry_line.line_disposition = 'ACTIVE'
          and pantry_line.pantry_need_approval_snapshot_id = pantry_member.pantry_need_approval_snapshot_id
          and pantry_line.pantry_active_snapshot_member_line_id = pantry_member.pantry_need_line_id
      ) <> 1
  ) or exists (
    select 1
    from atlas_planning.theoretical_need_lines as pantry_line
    where pantry_line.need_generation_run_id = v_run.need_generation_run_id
      and pantry_line.contribution_family = 'PANTRY_DIRECT'
      and pantry_line.line_disposition = 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.pantry_need_approval_snapshot_lines as pantry_member
        where pantry_member.pantry_need_approval_snapshot_id = v_snapshot.pantry_need_approval_snapshot_id
          and pantry_member.pantry_need_line_id = pantry_line.pantry_active_snapshot_member_line_id
          and pantry_member.service_date between v_run.period_start and v_run.period_end
          and pantry_member.requested_quantity > 0
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'every and only positive in-period Pantry member requires one active contribution';
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
      and line.contribution_family = 'RECIPE_DERIVED'
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
      and line.contribution_family = 'RECIPE_DERIVED'
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
        or line.contribution_family <> 'RECIPE_DERIVED'
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
      and line.contribution_family = 'RECIPE_DERIVED'
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
    from atlas_planning.theoretical_need_lines as line
    join atlas_planning.theoretical_need_lines as prior
      on prior.need_generation_run_id = v_run.predecessor_need_generation_run_id
     and prior.contribution_family = 'PANTRY_DIRECT'
     and prior.pantry_need_line_id = line.pantry_need_line_id
     and prior.line_disposition = 'ACTIVE'
    where line.need_generation_run_id = v_run.need_generation_run_id
      and line.contribution_family = 'PANTRY_DIRECT'
      and line.predecessor_theoretical_need_line_id is distinct from
        prior.theoretical_need_line_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'an existing stable Pantry line requires its exact direct predecessor';
  end if;

  if exists (
    select 1
    from atlas_planning.theoretical_need_lines as line
    join atlas_planning.theoretical_need_lines as predecessor
      on predecessor.theoretical_need_line_id = line.predecessor_theoretical_need_line_id
    join atlas_planning.need_generation_runs as predecessor_run
      on predecessor_run.need_generation_run_id = predecessor.need_generation_run_id
    where line.need_generation_run_id = v_run.need_generation_run_id
      and line.contribution_family = 'PANTRY_DIRECT'
      and (
        predecessor.contribution_family <> 'PANTRY_DIRECT'
        or v_run.predecessor_need_generation_run_id is null
        or line.predecessor_need_generation_run_id <> v_run.predecessor_need_generation_run_id
        or predecessor.need_generation_run_id <> v_run.predecessor_need_generation_run_id
        or predecessor_run.planning_input_set_id <> v_run.planning_input_set_id
        or predecessor_run.period_start <> v_run.period_start
        or predecessor_run.period_end <> v_run.period_end
        or predecessor.pantry_need_line_id <> line.pantry_need_line_id
        or (
          (
            predecessor.service_date <> line.service_date
            or predecessor.school_id <> line.school_id
            or predecessor.delivery_location_id <> line.delivery_location_id
            or predecessor.ingredient_id <> line.ingredient_id
          )
          and not exists (
            select 1
            from atlas_planning.need_generation_issues as issue
            where issue.need_generation_run_id = v_run.need_generation_run_id
              and issue.issue_code = 'INVALID_PREDECESSOR'
              and issue.severity = 'BLOCKING'
              and issue.pantry_need_line_id = line.pantry_need_line_id
          )
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Pantry predecessor requires the direct stable line and fixed operational anchors';
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_issues as issue
    where issue.need_generation_run_id = v_run.need_generation_run_id
      and issue.issue_code = 'INVALID_PREDECESSOR'
      and issue.pantry_need_line_id is not null
      and not exists (
        select 1
        from atlas_planning.theoretical_need_lines as line
        join atlas_planning.theoretical_need_lines as predecessor
          on predecessor.theoretical_need_line_id = line.predecessor_theoretical_need_line_id
        where line.need_generation_run_id = v_run.need_generation_run_id
          and line.contribution_family = 'PANTRY_DIRECT'
          and line.pantry_need_line_id = issue.pantry_need_line_id
          and (
            predecessor.service_date <> line.service_date
            or predecessor.school_id <> line.school_id
            or predecessor.delivery_location_id <> line.delivery_location_id
            or predecessor.ingredient_id <> line.ingredient_id
          )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'an INVALID_PREDECESSOR blocker requires one changed fixed Pantry anchor';
  end if;

  if v_run.predecessor_need_generation_run_id is not null and exists (
    select 1
    from atlas_planning.theoretical_need_lines as prior
    where prior.need_generation_run_id = v_run.predecessor_need_generation_run_id
      and prior.contribution_family = 'RECIPE_DERIVED'
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
    where prior.need_generation_run_id = v_run.predecessor_need_generation_run_id
      and prior.contribution_family = 'PANTRY_DIRECT'
      and prior.line_disposition = 'ACTIVE'
      and prior.service_date between v_run.period_start and v_run.period_end
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
          and issue.pantry_need_line_id = prior.pantry_need_line_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'every prior in-period Pantry contribution needs one active or removed successor';
  end if;

  if exists (
    select 1
    from atlas_planning.theoretical_need_lines as removed
    join atlas_planning.theoretical_need_lines as predecessor
      on predecessor.theoretical_need_line_id = removed.predecessor_theoretical_need_line_id
    where removed.need_generation_run_id = v_run.need_generation_run_id
      and removed.contribution_family = 'PANTRY_DIRECT'
      and removed.line_disposition = 'REMOVED'
      and (
        predecessor.contribution_family <> 'PANTRY_DIRECT'
        or predecessor.line_disposition <> 'ACTIVE'
        or predecessor.pantry_need_line_id <> removed.pantry_need_line_id
        or predecessor.service_date <> removed.service_date
        or predecessor.school_id <> removed.school_id
        or predecessor.delivery_location_id <> removed.delivery_location_id
        or predecessor.ingredient_id <> removed.ingredient_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'a removed Pantry contribution requires one exact prior active stable line';
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
      and prior.contribution_family = 'RECIPE_DERIVED'
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

  if v_run.predecessor_need_generation_run_id is not null and exists (
    select 1
    from atlas_planning.theoretical_need_lines as prior
    join atlas_planning.need_generation_runs as prior_run
      on prior_run.need_generation_run_id = prior.need_generation_run_id
    join atlas_planning.pantry_need_approval_snapshot_lines as pantry_member
      on pantry_member.pantry_need_approval_snapshot_id = v_snapshot.pantry_need_approval_snapshot_id
     and pantry_member.pantry_need_line_id = prior.pantry_need_line_id
     and pantry_member.service_date between v_run.period_start and v_run.period_end
    where prior_run.planning_input_set_id = v_run.planning_input_set_id
      and prior_run.attempt_ordinal < v_run.attempt_ordinal
      and prior.contribution_family = 'PANTRY_DIRECT'
      and prior.line_disposition = 'REMOVED'
      and (
        exists (
          select 1
          from atlas_planning.theoretical_need_lines as current_line
          where current_line.need_generation_run_id = v_run.need_generation_run_id
            and current_line.contribution_family = 'PANTRY_DIRECT'
            and current_line.line_disposition = 'ACTIVE'
            and current_line.pantry_need_line_id = prior.pantry_need_line_id
        )
        or not exists (
          select 1
          from atlas_planning.need_generation_issues as issue
          where issue.need_generation_run_id = v_run.need_generation_run_id
            and issue.issue_code = 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL'
            and issue.pantry_need_line_id = prior.pantry_need_line_id
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'removed Pantry-line reintroduction creates no line and requires the exact blocker';
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

create or replace function atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid;
  v_source_kind text;
  v_current_snapshot_id uuid;
begin
  v_batch_id := new.confirmed_need_batch_id;

  select batch.source_kind, batch.current_need_generation_release_snapshot_id
  into strict v_source_kind, v_current_snapshot_id
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;

  if v_source_kind = 'WHOLESALE' then
    if exists (
      select 1
      from atlas_planning.confirmed_need_line_revision_contributions contribution
      where contribution.confirmed_need_batch_id = v_batch_id
    ) then
      raise exception using errcode = '23514', message = 'Wholesale Confirmed Need revisions cannot have contributions';
    end if;
    return null;
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = v_batch_id
      and revision.source_kind = 'NEED_GENERATION'
      and not exists (
        select 1
        from atlas_planning.confirmed_need_line_revision_contributions contribution
        where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
      )
  ) then
    raise exception using errcode = '23514', message = 'Every Need Generation revision requires nonempty contribution membership';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
    join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_line_id = revision.confirmed_need_line_id
    join atlas_planning.need_generation_release_snapshot_lines snapshot_line
      on snapshot_line.need_generation_release_snapshot_line_id = contribution.need_generation_release_snapshot_line_id
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = contribution.theoretical_need_line_id
    join atlas_admin.schools school
      on school.school_id = contribution.school_id
    left join lateral (
      select prior_contribution.delivery_location_id
      from atlas_planning.confirmed_need_line_revision_contributions prior_contribution
      where prior_contribution.confirmed_need_batch_id = v_batch_id
        and prior_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
      order by prior_contribution.created_at,
               prior_contribution.confirmed_need_line_revision_contribution_id
      limit 1
    ) predecessor_contribution
      on theoretical.contribution_family = 'RECIPE_DERIVED'
     and theoretical.predecessor_theoretical_need_line_id is not null
    where contribution.confirmed_need_batch_id = v_batch_id
      and (
        revision.source_kind <> 'NEED_GENERATION'
        or contribution.confirmed_need_batch_id <> revision.confirmed_need_batch_id
        or contribution.confirmed_need_line_id <> revision.confirmed_need_line_id
        or contribution.need_generation_run_id <> revision.need_generation_run_id
        or contribution.need_generation_run_version <> revision.need_generation_run_version
        or contribution.need_generation_release_snapshot_id <> revision.need_generation_release_snapshot_id
        or snapshot_line.need_generation_release_snapshot_id <> revision.need_generation_release_snapshot_id
        or snapshot_line.need_generation_run_id <> revision.need_generation_run_id
        or snapshot_line.released_run_version <> revision.need_generation_run_version
        or snapshot_line.theoretical_need_line_id <> theoretical.theoretical_need_line_id
        or theoretical.need_generation_run_id <> revision.need_generation_run_id
        or theoretical.line_disposition <> 'ACTIVE'
        or theoretical.service_date <> line.service_date
        or theoretical.school_id <> line.school_id
        or theoretical.ingredient_id <> line.ingredient_id
        or theoretical.unit_id <> line.controlled_unit_id
        or theoretical.theoretical_quantity <> contribution.source_theoretical_quantity
        or contribution.service_date <> line.service_date
        or contribution.customer_id <> line.customer_id
        or contribution.school_id <> line.school_id
        or contribution.delivery_location_id <> line.delivery_location_id
        or contribution.ingredient_id <> line.ingredient_id
        or contribution.source_unit_id <> line.controlled_unit_id
        or contribution.controlled_unit_id <> line.controlled_unit_id
        or contribution.controlled_contribution_quantity <> contribution.source_theoretical_quantity
        or school.customer_id <> line.customer_id
        or contribution.delivery_location_id is distinct from case
          when theoretical.contribution_family = 'PANTRY_DIRECT'
            then theoretical.delivery_location_id
          when theoretical.predecessor_theoretical_need_line_id is not null
            then predecessor_contribution.delivery_location_id
          when revision.is_current
            then school.default_delivery_location_id
          else revision.delivery_location_id
        end
      )
  ) then
    raise exception using errcode = '23514', message = 'Need Generation contribution facts are not exact active release facts';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = v_batch_id
      and revision.source_kind = 'NEED_GENERATION'
      and (
        revision.theoretical_quantity is distinct from (
          select sum(contribution.controlled_contribution_quantity)
          from atlas_planning.confirmed_need_line_revision_contributions contribution
          where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
        )
        or exists (
          select 1
          from atlas_planning.need_generation_release_snapshot_lines snapshot_line
          join atlas_planning.theoretical_need_lines theoretical
            on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
          where snapshot_line.need_generation_release_snapshot_id = revision.need_generation_release_snapshot_id
            and theoretical.line_disposition = 'ACTIVE'
            and theoretical.contribution_family = 'RECIPE_DERIVED'
            and theoretical.predecessor_theoretical_need_line_id is not null
            and theoretical.service_date = revision.service_date
            and theoretical.school_id = revision.school_id
            and theoretical.ingredient_id = revision.ingredient_id
            and theoretical.unit_id = revision.unit_id
            and not exists (
              select 1
              from atlas_planning.confirmed_need_line_revision_contributions predecessor_contribution
              where predecessor_contribution.confirmed_need_batch_id = v_batch_id
                and predecessor_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
            )
        )
        or exists (
          select 1
          from atlas_planning.need_generation_release_snapshot_lines snapshot_line
          join atlas_planning.theoretical_need_lines theoretical
            on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
          join atlas_admin.schools school
            on school.school_id = theoretical.school_id
          left join lateral (
            select prior_contribution.delivery_location_id
            from atlas_planning.confirmed_need_line_revision_contributions prior_contribution
            where prior_contribution.confirmed_need_batch_id = v_batch_id
              and prior_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
            order by prior_contribution.created_at,
                     prior_contribution.confirmed_need_line_revision_contribution_id
            limit 1
          ) predecessor_contribution
            on theoretical.contribution_family = 'RECIPE_DERIVED'
           and theoretical.predecessor_theoretical_need_line_id is not null
          where snapshot_line.need_generation_release_snapshot_id = revision.need_generation_release_snapshot_id
            and theoretical.line_disposition = 'ACTIVE'
            and theoretical.service_date = revision.service_date
            and theoretical.school_id = revision.school_id
            and theoretical.ingredient_id = revision.ingredient_id
            and theoretical.unit_id = revision.unit_id
            and revision.delivery_location_id is not distinct from case
              when theoretical.contribution_family = 'PANTRY_DIRECT'
                then theoretical.delivery_location_id
              when theoretical.predecessor_theoretical_need_line_id is not null
                then predecessor_contribution.delivery_location_id
              when revision.is_current
                then school.default_delivery_location_id
              else revision.delivery_location_id
            end
            and not exists (
              select 1
              from atlas_planning.confirmed_need_line_revision_contributions contribution
              where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
                and contribution.theoretical_need_line_id = theoretical.theoretical_need_line_id
            )
        )
      )
  ) then
    raise exception using errcode = '23514', message = 'Need Generation revision membership is incomplete or its total is inexact';
  end if;

  if exists (
    select snapshot_line.theoretical_need_line_id
    from atlas_planning.need_generation_release_snapshot_lines snapshot_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
    left join atlas_planning.confirmed_need_line_revision_contributions contribution
      on contribution.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
    left join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
      and revision.confirmed_need_batch_id = v_batch_id
      and revision.is_current
    where snapshot_line.need_generation_release_snapshot_id = v_current_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    group by snapshot_line.theoretical_need_line_id
    having count(revision.confirmed_need_line_revision_id) <> 1
  ) then
    raise exception using errcode = '23514', message = 'Current Need Generation revisions must exactly partition the active release';
  end if;

  return null;
end;
$$;

grant atlas_planning_materialization_runtime to postgres with set true;
grant create on schema atlas_api to atlas_planning_materialization_runtime;
set role atlas_planning_materialization_runtime;
create or replace function atlas_api.create_confirmed_needs_from_generation(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'create_confirmed_needs_from_generation';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_run_id uuid;
  v_run_version bigint;
  v_batch_id uuid;
  v_expected_version bigint;
  v_run atlas_planning.need_generation_runs%rowtype;
  v_old_run atlas_planning.need_generation_runs%rowtype;
  v_release atlas_planning.need_generation_release_snapshots%rowtype;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_initial boolean;
  v_active_count integer := 0;
  v_school_count integer := 0;
  v_group_count integer := 0;
  v_release_member_count integer := 0;
  v_created_line_count integer := 0;
  v_reused_line_count integer := 0;
  v_retired_line_count integer := 0;
  v_created_revision_count integer := 0;
  v_created_contribution_count integer := 0;
  v_current_revision_count integer := 0;
  v_superseded_revision_count integer := 0;
  v_old_current_count integer := 0;
  v_reused_old_count integer := 0;
  v_batch_version_before bigint;
  v_batch_version_after bigint;
  v_event_type text;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_counts jsonb;
  v_response jsonb;
begin
  v_error := atlas_core.pa_06e_h0cb_validate_materialization_request(request);
  if v_error is not null then return v_error; end if;

  v_run_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'need_generation_run_id');
  v_run_version := atlas_core.pa_05b_safe_bigint(v_payload ->> 'need_generation_run_version');
  v_batch_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id');
  v_expected_version := atlas_core.pa_05b_safe_bigint(request ->> 'expected_version');
  v_initial := v_batch_id is null;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'PLANNING', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  if v_actor_context ->> 'actor_type' <> 'HUMAN' then
    return atlas_core.pa_05b_command_error(
      request, 'DELEGATION_NOT_SUPPORTED',
      'Only an active authenticated human actor may materialize Confirmed Need.',
      'PLANNING', v_command_name
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select source_run.* into v_run
  from atlas_planning.need_generation_runs source_run
  where source_run.need_generation_run_id = v_run_id;
  if not found or v_run.run_status <> 'RELEASED_FOR_CONFIRMATION' then
    return atlas_core.pa_05b_command_error(
      request, 'GENERATION_NOT_RELEASED',
      'The requested Need Generation run is not released for confirmation.',
      'PLANNING', v_command_name
    );
  end if;
  if v_run.version <> v_run_version then
    return atlas_core.pa_05b_command_error(
      request, 'SOURCE_REVISION_STALE',
      'The requested Need Generation run version is stale.',
      'PLANNING', v_command_name, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
  end if;

  select release_snapshot.* into v_release
  from atlas_planning.need_generation_release_snapshots release_snapshot
  where release_snapshot.need_generation_run_id = v_run_id;
  if not found or v_release.released_run_version <> v_run_version then
    return atlas_core.pa_05b_command_error(
      request, 'GENERATION_NOT_RELEASED',
      'The exact immutable Need Generation release snapshot is unavailable.',
      'PLANNING', v_command_name
    );
  end if;

  if not v_initial then
    select target_batch.* into v_batch
    from atlas_planning.confirmed_need_batches target_batch
    where target_batch.confirmed_need_batch_id = v_batch_id;
    if not found or v_batch.source_kind <> 'NEED_GENERATION' then
      return atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED',
        'The requested Confirmed Need batch could not be validated.',
        'PLANNING', v_command_name
      );
    end if;
  end if;

  -- Reuse the common helper for capability and ordinary scope semantics. A
  -- SCOPE_DENIED result is refined below against the complete H0C four-kind
  -- scope set, including SCHOOL, which predates no generic PA-05B parameter.
  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'confirmed_need_generation.materialize',
    'PLANNING', v_command_name, null, null, null
  );
  if v_authorization_error is not null
     and v_authorization_error ->> 'error_code' <> 'SCOPE_DENIED' then
    return v_authorization_error;
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on not v_initial
     and old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
     and exists (
       select 1
       from atlas_planning.confirmed_need_line_revisions old_revision
       where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
         and old_revision.is_current
     )
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and not exists (
        select 1
        from atlas_core.actor_scopes scope
        where scope.actor_id = v_actor_id
          and scope.scope_status = 'ACTIVE'
          and scope.effective_from <= pg_catalog.transaction_timestamp()
          and (scope.effective_to is null or scope.effective_to > pg_catalog.transaction_timestamp())
          and (
            scope.scope_kind = 'GLOBAL'
            or (scope.scope_kind = 'CUSTOMER' and scope.customer_id = school.customer_id)
            or (scope.scope_kind = 'SCHOOL' and scope.school_id = school.school_id)
            or (
              scope.scope_kind = 'DELIVERY_LOCATION'
              and scope.delivery_location_id = case
                when theoretical.contribution_family = 'PANTRY_DIRECT'
                  then theoretical.delivery_location_id
                when old_contribution.delivery_location_id is not null
                  then old_contribution.delivery_location_id
                else school.default_delivery_location_id
              end
            )
          )
      )
  ) then
    return atlas_core.pa_05b_command_error(
      request, 'SCOPE_DENIED',
      'The actor does not cover the complete released contribution set.',
      'PLANNING', v_command_name
    );
  end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_command_name,
    'PLANNING',
    case when v_initial
      then 'need-generation-run:' || v_run_id::text
      else 'confirmed-need-batch:' || v_batch_id::text
    end
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform pg_catalog.set_config('lock_timeout', '5s', true);
  perform pg_catalog.set_config('statement_timeout', '120s', true);

  -- Admin reference locks, always UUID ordered.
  perform 1
  from atlas_admin.customers customer
  where customer.customer_id in (
    select school.customer_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  )
  order by customer.customer_id for key share;
  perform 1
  from atlas_admin.schools school
  where school.school_id in (
    select theoretical.school_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  )
  order by school.school_id for key share;
  perform 1
  from atlas_admin.delivery_locations location
  where location.delivery_location_id in (
    select school.default_delivery_location_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    union
    select theoretical.delivery_location_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.contribution_family = 'PANTRY_DIRECT'
      and theoretical.line_disposition = 'ACTIVE'
    union
    select contribution.delivery_location_id
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
    where not v_initial
      and contribution.confirmed_need_batch_id = v_batch_id
      and revision.is_current
  )
  order by location.delivery_location_id for key share;
  perform 1
  from atlas_admin.ingredients ingredient
  where ingredient.ingredient_id in (
    select theoretical.ingredient_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  ) order by ingredient.ingredient_id for key share;
  perform 1
  from atlas_admin.units unit_record
  where unit_record.unit_id in (
    select theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  ) order by unit_record.unit_id for key share;

  -- Typed Recipe/source evidence precedes mutable Planning aggregate locks.
  perform 1 from atlas_planning.need_generation_input_snapshots snapshot
    where snapshot.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by snapshot.need_generation_input_snapshot_id for key share;
  perform 1 from atlas_planning.need_generation_recipe_selections selection
    where selection.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by selection.need_generation_recipe_selection_id for key share;
  perform 1 from atlas_planning.need_generation_recipe_line_uses recipe_use
    where recipe_use.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by recipe_use.need_generation_recipe_line_use_id for key share;

  perform 1 from atlas_planning.planning_input_sets input_set
    where input_set.planning_input_set_id = v_run.planning_input_set_id for key share;
  perform 1 from atlas_planning.planning_input_evaluations evaluation
    where evaluation.planning_input_set_id = v_run.planning_input_set_id
    order by evaluation.planning_input_evaluation_id for key share;
  perform 1 from atlas_planning.need_generation_runs source_run
    where source_run.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by source_run.need_generation_run_id for update;
  perform 1 from atlas_planning.need_generation_release_snapshots release_snapshot
    where release_snapshot.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by release_snapshot.need_generation_release_snapshot_id for key share;
  perform 1 from atlas_planning.need_generation_release_snapshot_lines release_line
    where release_line.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by release_line.need_generation_release_snapshot_line_id for key share;
  perform 1 from atlas_planning.theoretical_need_lines theoretical
    where theoretical.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by theoretical.theoretical_need_line_id for key share;

  if not v_initial then
    perform 1 from atlas_planning.confirmed_need_batches target_batch
      where target_batch.confirmed_need_batch_id = v_batch_id for update;
    perform 1 from atlas_planning.confirmed_need_lines target_line
      where target_line.confirmed_need_batch_id = v_batch_id
      order by target_line.confirmed_need_line_id for key share;
    perform 1 from atlas_planning.confirmed_need_line_revisions target_revision
      where target_revision.confirmed_need_batch_id = v_batch_id and target_revision.is_current
      order by target_revision.confirmed_need_line_revision_id for update;
  end if;

  -- Reread authoritative state after the deterministic lock set.
  select source_run.* into v_run
  from atlas_planning.need_generation_runs source_run
  where source_run.need_generation_run_id = v_run_id;
  select release_snapshot.* into v_release
  from atlas_planning.need_generation_release_snapshots release_snapshot
  where release_snapshot.need_generation_run_id = v_run_id;
  if v_run.run_status <> 'RELEASED_FOR_CONFIRMATION'
     or v_run.version <> v_run_version
     or v_release.released_run_version <> v_run_version
     or v_release.need_generation_input_snapshot_id <> v_run.input_snapshot_id then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_REVISION_STALE',
      'The released Need Generation source changed before materialization.',
      'PLANNING', v_command_name, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_release_member_count
  from atlas_planning.need_generation_release_snapshot_lines release_line
  where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id;
  select count(*)::integer into v_active_count
  from atlas_planning.need_generation_release_snapshot_lines release_line
  join atlas_planning.theoretical_need_lines theoretical
    on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
  where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    and theoretical.line_disposition = 'ACTIVE';

  if not exists (
    select 1 from atlas_planning.need_generation_input_snapshots snapshot
    where snapshot.need_generation_input_snapshot_id = v_run.input_snapshot_id
      and snapshot.need_generation_run_id = v_run_id
  ) or exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    left join atlas_planning.need_generation_recipe_selections selection
      on selection.need_generation_recipe_selection_id = theoretical.need_generation_recipe_selection_id
     and selection.need_generation_run_id = theoretical.need_generation_run_id
    left join atlas_planning.need_generation_recipe_line_uses recipe_use
      on recipe_use.need_generation_recipe_line_use_id = theoretical.need_generation_recipe_line_use_id
     and recipe_use.need_generation_run_id = theoretical.need_generation_run_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.contribution_family = 'RECIPE_DERIVED'
      and (selection.need_generation_recipe_selection_id is null or recipe_use.need_generation_recipe_line_use_id is null)
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_LINEAGE_INCOMPLETE',
      'The released source does not retain its complete typed input and contribution lineage.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_release_member_count <> v_release.generated_line_count
     or v_active_count <> v_release.active_line_count
     or v_release.generated_line_count <> v_release.active_line_count + v_release.removed_line_count then
    v_error := atlas_core.pa_05b_command_error(
      request, 'CONTRIBUTION_MEMBERSHIP_INVALID',
      'The immutable release membership does not match its released counts.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_active_count = 0
     and (
       v_initial
       or v_release_member_count = 0
       or exists (
         select 1
         from atlas_planning.need_generation_release_snapshot_lines release_line
         join atlas_planning.theoretical_need_lines theoretical
           on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
         where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
           and not (
             theoretical.contribution_family = 'PANTRY_DIRECT'
             and theoretical.line_disposition = 'REMOVED'
           )
       )
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'EMPTY_ACTIVE_RELEASE',
      'The released Need Generation result has no active contribution.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity = 0
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'ZERO_ACTIVE_CONTRIBUTION_POLICY_REQUIRED',
      'An active released contribution has zero quantity.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    left join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_admin.customers customer on customer.customer_id = school.customer_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on not v_initial
     and old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
     and exists (
       select 1
       from atlas_planning.confirmed_need_line_revisions old_revision
       where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
         and old_revision.is_current
     )
    left join atlas_admin.delivery_locations location
      on location.delivery_location_id = case
        when theoretical.contribution_family = 'PANTRY_DIRECT'
          then theoretical.delivery_location_id
        when old_contribution.delivery_location_id is not null
          then old_contribution.delivery_location_id
        else school.default_delivery_location_id
      end
     and location.customer_id = school.customer_id
    left join atlas_admin.ingredients ingredient on ingredient.ingredient_id = theoretical.ingredient_id
    left join atlas_admin.units unit_record on unit_record.unit_id = theoretical.unit_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and (
        theoretical.service_date < v_run.period_start
        or theoretical.service_date > v_run.period_end
        or school.school_status is distinct from 'ACTIVE'
        or school.customer_type is distinct from 'SCHOOL_CATERING'
        or customer.customer_type is distinct from 'SCHOOL_CATERING'
        or customer.customer_status is distinct from 'ACTIVE'
        or location.location_status is distinct from 'ACTIVE'
        or ingredient.ingredient_status is distinct from 'ACTIVE'
        or unit_record.unit_status is distinct from 'ACTIVE'
      )
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_MAPPING_INCOMPLETE',
      'The released contribution set has an inactive or inconsistent operational reference.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(distinct theoretical.school_id)::integer into v_school_count
  from atlas_planning.need_generation_release_snapshot_lines release_line
  join atlas_planning.theoretical_need_lines theoretical
    on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
  where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    and theoretical.line_disposition = 'ACTIVE';

  select count(*)::integer into v_group_count
  from (
    select theoretical.service_date, school.customer_id, theoretical.school_id,
           case
             when theoretical.contribution_family = 'PANTRY_DIRECT'
               then theoretical.delivery_location_id
             when old_contribution.delivery_location_id is not null
               then old_contribution.delivery_location_id
             else school.default_delivery_location_id
           end delivery_location_id,
           theoretical.ingredient_id, theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on not v_initial
     and old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
     and exists (
       select 1 from atlas_planning.confirmed_need_line_revisions old_revision
       where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
         and old_revision.is_current
     )
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    group by theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               when old_contribution.delivery_location_id is not null
                 then old_contribution.delivery_location_id
               else school.default_delivery_location_id
             end,
             theoretical.ingredient_id, theoretical.unit_id
  ) grouped;

  if (v_run.period_end - v_run.period_start + 1) > 14
     or v_school_count > 500
     or v_active_count > 25000
     or v_group_count > 15000 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'MATERIALIZATION_LIMIT_EXCEEDED',
      'The released result exceeds a bounded materialization limit.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_initial then
    if exists (
      select 1 from atlas_planning.confirmed_need_batches existing_batch
      where existing_batch.source_kind = 'NEED_GENERATION'
        and existing_batch.origin_need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'This released Need Generation result already has a Confirmed Need batch.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    insert into atlas_planning.confirmed_need_batches (
      wholesale_order_id,
      period_start,
      period_end,
      batch_status,
      version,
      created_by_actor_id,
      source_kind,
      origin_need_generation_run_id,
      origin_need_generation_run_version,
      origin_need_generation_release_snapshot_id,
      current_need_generation_run_id,
      current_need_generation_run_version,
      current_need_generation_release_snapshot_id
    ) values (
      null,
      v_run.period_start,
      v_run.period_end,
      'DRAFT_REVIEW',
      1,
      v_actor_id,
      'NEED_GENERATION',
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id
    ) returning confirmed_need_batch_id into v_batch_id;

    insert into atlas_planning.confirmed_need_lines (
      confirmed_need_batch_id,
      wholesale_order_line_id,
      source_kind,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      controlled_unit_id
    )
    select
      v_batch_id,
      null,
      'NEED_GENERATION',
      theoretical.service_date,
      school.customer_id,
      theoretical.school_id,
      case
        when theoretical.contribution_family = 'PANTRY_DIRECT'
          then theoretical.delivery_location_id
        else school.default_delivery_location_id
      end,
      theoretical.ingredient_id,
      theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    group by theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               else school.default_delivery_location_id
             end,
             theoretical.ingredient_id, theoretical.unit_id;
    get diagnostics v_created_line_count = row_count;

    insert into atlas_planning.confirmed_need_line_revisions (
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
      source_kind,
      confirmed_need_batch_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id
    )
    select
      target_line.confirmed_need_line_id,
      1,
      null,
      target_line.ingredient_id,
      sum(theoretical.theoretical_quantity),
      sum(theoretical.theoretical_quantity),
      target_line.controlled_unit_id,
      'DRAFT',
      true,
      null,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      v_actor_id,
      'NEED_GENERATION',
      v_batch_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      target_line.service_date,
      target_line.customer_id,
      target_line.school_id,
      target_line.delivery_location_id
    from atlas_planning.confirmed_need_lines target_line
    join atlas_planning.need_generation_release_snapshot_lines release_line
      on release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
     and theoretical.service_date = target_line.service_date
     and theoretical.school_id = target_line.school_id
    join atlas_admin.schools school
      on school.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       else school.default_delivery_location_id
     end
     and theoretical.ingredient_id = target_line.ingredient_id
     and theoretical.unit_id = target_line.controlled_unit_id
    where target_line.confirmed_need_batch_id = v_batch_id
      and target_line.source_kind = 'NEED_GENERATION'
    group by target_line.confirmed_need_line_id, target_line.ingredient_id,
             target_line.controlled_unit_id, target_line.service_date,
             target_line.customer_id, target_line.school_id, target_line.delivery_location_id;
    get diagnostics v_created_revision_count = row_count;

    insert into atlas_planning.confirmed_need_line_revision_contributions (
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
      controlled_contribution_quantity
    )
    select
      v_batch_id,
      target_line.confirmed_need_line_id,
      target_revision.confirmed_need_line_revision_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      release_line.need_generation_release_snapshot_line_id,
      theoretical.theoretical_need_line_id,
      theoretical.service_date,
      target_line.customer_id,
      theoretical.school_id,
      target_line.delivery_location_id,
      theoretical.ingredient_id,
      theoretical.unit_id,
      target_line.controlled_unit_id,
      theoretical.theoretical_quantity,
      theoretical.theoretical_quantity
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
    join atlas_admin.schools school
      on school.school_id = theoretical.school_id
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.source_kind = 'NEED_GENERATION'
     and target_line.service_date = theoretical.service_date
     and target_line.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       else school.default_delivery_location_id
     end
     and target_line.ingredient_id = theoretical.ingredient_id
     and target_line.controlled_unit_id = theoretical.unit_id
    join atlas_planning.confirmed_need_line_revisions target_revision
      on target_revision.confirmed_need_line_id = target_line.confirmed_need_line_id
     and target_revision.is_current
     and target_revision.need_generation_run_id = v_run_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id;
    get diagnostics v_created_contribution_count = row_count;

    v_reused_line_count := 0;
    v_retired_line_count := 0;
    v_current_revision_count := v_created_revision_count;
    v_superseded_revision_count := 0;
    v_batch_version_before := null;
    v_batch_version_after := 1;
    v_event_type := 'ConfirmedNeedsCreated';
  else
    select target_batch.* into v_batch
    from atlas_planning.confirmed_need_batches target_batch
    where target_batch.confirmed_need_batch_id = v_batch_id;

    if v_batch.version <> v_expected_version then
      v_error := atlas_core.pa_05b_command_error(
        request, 'STALE_VERSION',
        'The Confirmed Need batch changed. Refresh before rematerialization.',
        'PLANNING', v_command_name, false, '[]'::jsonb,
        pg_catalog.jsonb_build_array(v_batch_id), v_batch.version
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
    if v_batch.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF' then
      v_error := atlas_core.pa_05b_command_error(
        request, 'DOWNSTREAM_CORRECTION_REQUIRED',
        'Released Confirmed Need requires an explicit downstream correction policy.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
    if v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then
      v_error := atlas_core.pa_05b_command_error(
        request, 'REOPEN_REQUIRED',
        'The Confirmed Need batch must be explicitly reopened before rematerialization.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    select prior_run.* into v_old_run
    from atlas_planning.need_generation_runs prior_run
    where prior_run.need_generation_run_id = v_batch.current_need_generation_run_id;
    if not found
       or v_batch.current_need_generation_run_version <> v_old_run.version
       or not exists (
         select 1 from atlas_planning.need_generation_release_snapshots old_release
         where old_release.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
           and old_release.need_generation_run_id = v_old_run.need_generation_run_id
           and old_release.released_run_version = v_old_run.version
       ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_REVISION_STALE',
        'The Confirmed Need batch current source is stale.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
    if v_run.predecessor_need_generation_run_id is distinct from v_old_run.need_generation_run_id
       or v_run.planning_input_set_id <> v_old_run.planning_input_set_id
       or v_run.period_start <> v_old_run.period_start
       or v_run.period_end <> v_old_run.period_end
       or v_batch.period_start <> v_run.period_start
       or v_batch.period_end <> v_run.period_end then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_SUCCESSOR_AMBIGUOUS',
        'The requested run is not the exact direct released successor of the batch current source.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines new_release_line
      join atlas_planning.theoretical_need_lines new_theoretical
        on new_theoretical.theoretical_need_line_id = new_release_line.theoretical_need_line_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = new_theoretical.predecessor_theoretical_need_line_id
      left join atlas_planning.confirmed_need_line_revisions old_revision
        on old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
       and old_revision.is_current
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and new_theoretical.line_disposition = 'ACTIVE'
        and new_theoretical.predecessor_theoretical_need_line_id is not null
        and (
          new_theoretical.predecessor_need_generation_run_id <> v_old_run.need_generation_run_id
          or old_contribution.confirmed_need_line_revision_contribution_id is null
          or old_revision.confirmed_need_line_revision_id is null
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_MAPPING_INCOMPLETE',
        'A successor contribution is not mapped to exactly one prior current contribution.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select old_contribution.theoretical_need_line_id
      from atlas_planning.confirmed_need_line_revision_contributions old_contribution
      join atlas_planning.confirmed_need_line_revisions old_revision
        on old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
      left join atlas_planning.theoretical_need_lines successor
        on successor.predecessor_theoretical_need_line_id = old_contribution.theoretical_need_line_id
       and successor.need_generation_run_id = v_run_id
      left join atlas_planning.need_generation_release_snapshot_lines successor_member
        on successor_member.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
       and successor_member.theoretical_need_line_id = successor.theoretical_need_line_id
      where old_contribution.confirmed_need_batch_id = v_batch_id
        and old_revision.is_current
      group by old_contribution.theoretical_need_line_id
      having count(successor_member.need_generation_release_snapshot_line_id) <> 1
         or count(successor_member.need_generation_release_snapshot_line_id)
              filter (
                where successor.line_disposition = 'ACTIVE'
                   or (
                     successor.contribution_family = 'PANTRY_DIRECT'
                     and successor.line_disposition = 'REMOVED'
                   )
              ) <> 1
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_REMOVAL_POLICY_REQUIRED',
        'A prior contribution lacks one accepted active or Pantry removal successor.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines new_release_line
      join atlas_planning.theoretical_need_lines successor
        on successor.theoretical_need_line_id = new_release_line.theoretical_need_line_id
      join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and successor.line_disposition = 'ACTIVE'
        and (
          successor.service_date <> old_contribution.service_date
          or successor.school_id <> old_contribution.school_id
          or successor.unit_id <> old_contribution.source_unit_id
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_SPLIT_MERGE_POLICY_REQUIRED',
        'The successor changes an operational fact across the no-conversion or split-merge boundary.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines new_release_line
      join atlas_planning.theoretical_need_lines successor
        on successor.theoretical_need_line_id = new_release_line.theoretical_need_line_id
      join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = successor.school_id
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and successor.line_disposition = 'ACTIVE'
        and successor.contribution_family = 'RECIPE_DERIVED'
        and school.default_delivery_location_id <> old_contribution.delivery_location_id
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'OPERATIONAL_IDENTITY_UNAPPROVED',
        'A School default destination changed for an existing contribution.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    select count(*)::integer into v_old_current_count
    from atlas_planning.confirmed_need_line_revisions old_revision
    where old_revision.confirmed_need_batch_id = v_batch_id
      and old_revision.is_current;
    if v_old_current_count = 0 or exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions old_revision
      where old_revision.confirmed_need_batch_id = v_batch_id
        and old_revision.is_current
        and row(
          old_revision.need_generation_run_id,
          old_revision.need_generation_run_version,
          old_revision.need_generation_release_snapshot_id
        ) is distinct from row(
          v_batch.current_need_generation_run_id,
          v_batch.current_need_generation_run_version,
          v_batch.current_need_generation_release_snapshot_id
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'CONTRIBUTION_MEMBERSHIP_INVALID',
        'The current Confirmed Need revision partition is incomplete or stale.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions old_revision
      where old_revision.confirmed_need_batch_id = v_batch_id
        and old_revision.is_current
        and old_revision.theoretical_quantity is distinct from (
          select sum(old_contribution.controlled_contribution_quantity)
          from atlas_planning.confirmed_need_line_revision_contributions old_contribution
          where old_contribution.confirmed_need_line_revision_id = old_revision.confirmed_need_line_revision_id
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'CONTRIBUTION_TOTAL_MISMATCH',
        'A current Confirmed Need revision does not equal its complete contribution membership.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    -- Add only genuinely absent stable identities; exact identities are reused.
    insert into atlas_planning.confirmed_need_lines (
      confirmed_need_batch_id,
      wholesale_order_line_id,
      source_kind,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      controlled_unit_id
    )
    select
      v_batch_id,
      null,
      'NEED_GENERATION',
      grouped.service_date,
      grouped.customer_id,
      grouped.school_id,
      grouped.delivery_location_id,
      grouped.ingredient_id,
      grouped.unit_id
    from (
      select theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               when old_contribution.delivery_location_id is not null
                 then old_contribution.delivery_location_id
               else school.default_delivery_location_id
             end delivery_location_id,
             theoretical.ingredient_id, theoretical.unit_id
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
      group by theoretical.service_date, school.customer_id, theoretical.school_id,
               case
                 when theoretical.contribution_family = 'PANTRY_DIRECT'
                   then theoretical.delivery_location_id
                 when old_contribution.delivery_location_id is not null
                   then old_contribution.delivery_location_id
                 else school.default_delivery_location_id
               end,
               theoretical.ingredient_id, theoretical.unit_id
    ) grouped
    where not exists (
      select 1 from atlas_planning.confirmed_need_lines existing_line
      where existing_line.confirmed_need_batch_id = v_batch_id
        and existing_line.source_kind = 'NEED_GENERATION'
        and existing_line.service_date = grouped.service_date
        and existing_line.customer_id = grouped.customer_id
        and existing_line.school_id = grouped.school_id
        and existing_line.delivery_location_id = grouped.delivery_location_id
        and existing_line.ingredient_id = grouped.ingredient_id
        and existing_line.controlled_unit_id = grouped.unit_id
    );
    get diagnostics v_created_line_count = row_count;
    v_reused_line_count := v_group_count - v_created_line_count;

    update atlas_planning.confirmed_need_line_revisions old_revision
    set revision_status = 'SUPERSEDED', is_current = false
    where old_revision.confirmed_need_batch_id = v_batch_id
      and old_revision.is_current;
    get diagnostics v_superseded_revision_count = row_count;

    insert into atlas_planning.confirmed_need_line_revisions (
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
      source_kind,
      confirmed_need_batch_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id
    )
    select
      target_line.confirmed_need_line_id,
      coalesce(prior_revision.revision_number + 1, 1),
      null,
      target_line.ingredient_id,
      grouped.theoretical_total,
      grouped.theoretical_total,
      target_line.controlled_unit_id,
      'DRAFT',
      true,
      prior_revision.confirmed_need_line_revision_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      v_actor_id,
      'NEED_GENERATION',
      v_batch_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      target_line.service_date,
      target_line.customer_id,
      target_line.school_id,
      target_line.delivery_location_id
    from (
      select theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               when old_contribution.delivery_location_id is not null
                 then old_contribution.delivery_location_id
               else school.default_delivery_location_id
             end delivery_location_id,
             theoretical.ingredient_id, theoretical.unit_id,
             sum(theoretical.theoretical_quantity) theoretical_total
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
      group by theoretical.service_date, school.customer_id, theoretical.school_id,
               case
                 when theoretical.contribution_family = 'PANTRY_DIRECT'
                   then theoretical.delivery_location_id
                 when old_contribution.delivery_location_id is not null
                   then old_contribution.delivery_location_id
                 else school.default_delivery_location_id
               end,
               theoretical.ingredient_id, theoretical.unit_id
    ) grouped
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.service_date = grouped.service_date
     and target_line.customer_id = grouped.customer_id
     and target_line.school_id = grouped.school_id
     and target_line.delivery_location_id = grouped.delivery_location_id
     and target_line.ingredient_id = grouped.ingredient_id
     and target_line.controlled_unit_id = grouped.unit_id
    left join lateral (
      select prior.confirmed_need_line_revision_id, prior.revision_number
      from atlas_planning.confirmed_need_line_revisions prior
      where prior.confirmed_need_line_id = target_line.confirmed_need_line_id
      order by prior.revision_number desc
      limit 1
    ) prior_revision on true;
    get diagnostics v_created_revision_count = row_count;

    insert into atlas_planning.confirmed_need_line_revision_contributions (
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
      controlled_contribution_quantity
    )
    select
      v_batch_id,
      target_line.confirmed_need_line_id,
      target_revision.confirmed_need_line_revision_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      release_line.need_generation_release_snapshot_line_id,
      theoretical.theoretical_need_line_id,
      theoretical.service_date,
      target_line.customer_id,
      theoretical.school_id,
      target_line.delivery_location_id,
      theoretical.ingredient_id,
      theoretical.unit_id,
      target_line.controlled_unit_id,
      theoretical.theoretical_quantity,
      theoretical.theoretical_quantity
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.service_date = theoretical.service_date
     and target_line.customer_id = school.customer_id
     and target_line.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       when old_contribution.delivery_location_id is not null
         then old_contribution.delivery_location_id
       else school.default_delivery_location_id
     end
     and target_line.ingredient_id = theoretical.ingredient_id
     and target_line.controlled_unit_id = theoretical.unit_id
    join atlas_planning.confirmed_need_line_revisions target_revision
      on target_revision.confirmed_need_line_id = target_line.confirmed_need_line_id
     and target_revision.is_current
     and target_revision.need_generation_run_id = v_run_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id;
    get diagnostics v_created_contribution_count = row_count;

    select count(*)::integer into v_reused_old_count
    from atlas_planning.confirmed_need_line_revisions current_revision
    join atlas_planning.confirmed_need_line_revisions prior_revision
      on prior_revision.confirmed_need_line_revision_id = current_revision.predecessor_revision_id
    where current_revision.confirmed_need_batch_id = v_batch_id
      and current_revision.is_current
      and current_revision.need_generation_run_id = v_run_id
      and prior_revision.need_generation_run_id = v_old_run.need_generation_run_id;
    v_retired_line_count := v_old_current_count - v_reused_old_count;
    v_current_revision_count := v_created_revision_count;
    v_batch_version_before := v_batch.version;
    v_batch_version_after := v_batch.version + 1;
    v_event_type := 'ConfirmedNeedsRematerialized';

    update atlas_planning.confirmed_need_batches target_batch
    set current_need_generation_run_id = v_run_id,
        current_need_generation_run_version = v_run_version,
        current_need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id,
        version = v_batch_version_after,
        updated_at = pg_catalog.transaction_timestamp()
    where target_batch.confirmed_need_batch_id = v_batch_id;
  end if;

  v_counts := pg_catalog.jsonb_build_object(
    'created_confirmed_need_line_count', v_created_line_count,
    'reused_confirmed_need_line_count', v_reused_line_count,
    'retired_confirmed_need_line_count', v_retired_line_count,
    'created_line_revision_count', v_created_revision_count,
    'created_revision_contribution_count', v_created_contribution_count,
    'current_line_revision_count', v_current_revision_count,
    'superseded_line_revision_count', v_superseded_revision_count
  );

  insert into atlas_audit.domain_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    aggregate_version,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    occurred_at,
    payload_summary
  ) values (
    v_event_type,
    'PLANNING',
    'ConfirmedNeedBatch',
    v_batch_id,
    v_batch_version_after,
    v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'need_generation_run_id', v_run_id,
      'need_generation_run_version', v_run_version,
      'need_generation_release_snapshot_id', v_release.need_generation_release_snapshot_id,
      'service_period', pg_catalog.jsonb_build_object(
        'period_start', v_run.period_start,
        'period_end', v_run.period_end
      ),
      'result_counts', v_counts
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    aggregate_version_before,
    aggregate_version_after,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    reason_code,
    reason_note,
    before_summary,
    after_summary,
    source_interface,
    occurred_at
  ) values (
    v_event_type,
    'PLANNING',
    'ConfirmedNeedBatch',
    v_batch_id,
    v_batch_version_before,
    v_batch_version_after,
    v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,
    request ->> 'reason_code',
    request ->> 'reason_note',
    pg_catalog.jsonb_build_object(
      'batch_status', case when v_initial then null else v_batch.batch_status end,
      'version', v_batch_version_before,
      'current_source', case when v_initial then null else pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_batch.current_need_generation_run_id,
        'need_generation_run_version', v_batch.current_need_generation_run_version,
        'need_generation_release_snapshot_id', v_batch.current_need_generation_release_snapshot_id
      ) end,
      'result_counts', case when v_initial then null else pg_catalog.jsonb_build_object(
        'current_line_revision_count', v_old_current_count
      ) end
    ),
    pg_catalog.jsonb_build_object(
      'batch_status', 'DRAFT_REVIEW',
      'version', v_batch_version_after,
      'current_source', pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_run_id,
        'need_generation_run_version', v_run_version,
        'need_generation_release_snapshot_id', v_release.need_generation_release_snapshot_id
      ),
      'result_counts', v_counts
    ),
    'atlas_api',
    pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'need_generation_run_id', v_run_id,
      'confirmed_need_batch_id', v_batch_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'need_generation_run_version', v_run_version,
      'confirmed_need_batch_version', v_batch_version_after
    ),
    'result_counts', v_counts,
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', case when v_initial
      then 'Draft Confirmed Need created from the released generation result.'
      else 'Draft Confirmed Need rematerialized from the direct released successor.'
    end,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected or lock_not_available or query_canceled then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'PLANNING',
      v_command_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'Confirmed Need could not be materialized safely.',
      'PLANNING',
      v_command_name
    );
end;
$$;
reset role;
revoke create on schema atlas_api from atlas_planning_materialization_runtime;
revoke atlas_planning_materialization_runtime from postgres;
