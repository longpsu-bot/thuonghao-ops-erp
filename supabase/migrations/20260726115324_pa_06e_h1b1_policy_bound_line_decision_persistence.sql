-- PA-06E-H1B1 policy-bound Confirmed Need line-decision persistence.
-- Private, writerless structure only: no API, command, role, capability,
-- policy, positive grant, view, read model, event, or seed.

set role atlas_owner;

alter table atlas_planning.confirmed_need_line_revisions
  add constraint confirmed_need_line_revisions_decision_owner_key unique (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id
  );

alter table atlas_planning.confirmed_need_lines
  add column current_confirmed_need_line_decision_id uuid;

create table atlas_planning.confirmed_need_line_decisions (
  confirmed_need_line_decision_id uuid not null default gen_random_uuid(),
  confirmed_need_batch_id uuid not null,
  confirmed_need_line_id uuid not null,
  confirmed_need_line_revision_id uuid not null,
  source_kind text not null,
  service_date date not null,
  customer_id uuid not null,
  school_id uuid not null,
  delivery_location_id uuid not null,
  ingredient_id uuid not null,
  unit_id uuid not null,
  decision_number bigint not null,
  predecessor_decision_id uuid,
  decision_kind text not null,
  planning_quantity_policy_id uuid not null,
  planning_quantity_policy_revision_id uuid not null,
  theoretical_quantity_before numeric(20, 6) not null,
  proposed_quantity_before numeric(20, 6) not null,
  confirmed_quantity_after numeric(20, 6) not null,
  planning_tick_count numeric(20, 0) not null,
  reason_code text not null,
  reason_note text,
  decided_by_actor_id uuid not null,
  decided_at timestamptz not null,
  command_id uuid not null,
  confirmed_need_batch_version bigint not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint confirmed_need_line_decisions_pkey primary key (
    confirmed_need_line_decision_id
  ),
  constraint confirmed_need_line_decisions_line_id_decision_id_key unique (
    confirmed_need_line_id,
    confirmed_need_line_decision_id
  ),
  constraint confirmed_need_line_decisions_line_decision_number_key unique (
    confirmed_need_line_id,
    decision_number
  ),
  constraint confirmed_need_line_decisions_line_predecessor_key unique (
    confirmed_need_line_id,
    predecessor_decision_id
  ),
  constraint confirmed_need_line_decisions_command_line_key unique (
    command_id,
    confirmed_need_line_id
  ),
  constraint confirmed_need_line_decisions_decision_number_check check (
    decision_number > 0
  ),
  constraint confirmed_need_line_decisions_predecessor_shape_check check (
    (
      decision_number = 1
      and predecessor_decision_id is null
    )
    or (
      decision_number > 1
      and predecessor_decision_id is not null
    )
  ),
  constraint confirmed_need_line_decisions_predecessor_self_check check (
    predecessor_decision_id is null
    or predecessor_decision_id <> confirmed_need_line_decision_id
  ),
  constraint confirmed_need_line_decisions_source_kind_check check (
    source_kind = 'NEED_GENERATION'
  ),
  constraint confirmed_need_line_decisions_decision_kind_check check (
    decision_kind in (
      'UNCHANGED_PROPOSAL_ACCEPTED',
      'ADJUSTED_QUANTITY_CONFIRMED'
    )
  ),
  constraint confirmed_need_line_decisions_reason_code_check check (
    reason_code in (
      'PROPOSAL_ACCEPTED',
      'PLANNING_STEP_ADJUSTMENT',
      'OPERATIONAL_QUANTITY_ADJUSTMENT',
      'OTHER'
    )
  ),
  constraint confirmed_need_line_decisions_reason_note_check check (
    reason_note is null
    or (
      reason_note = btrim(reason_note)
      and char_length(reason_note) between 1 and 500
    )
  ),
  constraint confirmed_need_line_decisions_kind_reason_note_check check (
    (
      decision_kind = 'UNCHANGED_PROPOSAL_ACCEPTED'
      and reason_code = 'PROPOSAL_ACCEPTED'
      and (
        predecessor_decision_id is not null
        or reason_note is null
      )
    )
    or (
      decision_kind = 'ADJUSTED_QUANTITY_CONFIRMED'
      and reason_code in (
        'PLANNING_STEP_ADJUSTMENT',
        'OPERATIONAL_QUANTITY_ADJUSTMENT',
        'OTHER'
      )
      and (
        reason_code = 'PLANNING_STEP_ADJUSTMENT'
        or reason_note is not null
      )
    )
  ),
  constraint confirmed_need_line_decisions_correction_note_check check (
    predecessor_decision_id is null
    or reason_note is not null
  ),
  constraint confirmed_need_line_decisions_quantity_check check (
    theoretical_quantity_before >= 0
    and proposed_quantity_before >= 0
    and confirmed_quantity_after >= 0
    and planning_tick_count >= 0
  ),
  constraint confirmed_need_line_decisions_decision_quantity_shape_check check (
    (
      decision_kind = 'UNCHANGED_PROPOSAL_ACCEPTED'
      and confirmed_quantity_after = proposed_quantity_before
    )
    or (
      decision_kind = 'ADJUSTED_QUANTITY_CONFIRMED'
      and confirmed_quantity_after <> proposed_quantity_before
    )
  ),
  constraint confirmed_need_line_decisions_batch_version_check check (
    confirmed_need_batch_version > 0
  ),
  constraint confirmed_need_line_decisions_line_owner_fkey foreign key (
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id
  ) references atlas_planning.confirmed_need_lines (
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    controlled_unit_id
  ) on delete restrict,
  constraint confirmed_need_line_decisions_revision_owner_fkey foreign key (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id
  ) references atlas_planning.confirmed_need_line_revisions (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id
  ) on delete restrict,
  constraint confirmed_need_line_decisions_policy_revision_owner_fkey foreign key (
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id
  ) references atlas_planning.planning_quantity_policy_revisions (
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id
  ) on delete restrict,
  constraint confirmed_need_line_decisions_predecessor_fkey foreign key (
    confirmed_need_line_id,
    predecessor_decision_id
  ) references atlas_planning.confirmed_need_line_decisions (
    confirmed_need_line_id,
    confirmed_need_line_decision_id
  ) on delete restrict,
  constraint confirmed_need_line_decisions_decided_by_actor_fkey foreign key (
    decided_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint confirmed_need_line_decisions_command_fkey foreign key (
    command_id
  ) references atlas_core.command_receipts (command_id) on delete restrict
);

alter table atlas_planning.confirmed_need_lines
  add constraint confirmed_need_lines_current_decision_fkey foreign key (
    confirmed_need_line_id,
    current_confirmed_need_line_decision_id
  ) references atlas_planning.confirmed_need_line_decisions (
    confirmed_need_line_id,
    confirmed_need_line_decision_id
  ) on delete restrict
  deferrable initially deferred;

create index confirmed_need_line_decisions_line_owner_idx
  on atlas_planning.confirmed_need_line_decisions (
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id
  );

create index confirmed_need_line_decisions_revision_owner_idx
  on atlas_planning.confirmed_need_line_decisions (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id
  );

create index confirmed_need_line_decisions_policy_owner_idx
  on atlas_planning.confirmed_need_line_decisions (
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id
  );

create index confirmed_need_line_decisions_decided_by_actor_idx
  on atlas_planning.confirmed_need_line_decisions (decided_by_actor_id);

create index confirmed_need_lines_current_decision_idx
  on atlas_planning.confirmed_need_lines (
    confirmed_need_line_id,
    current_confirmed_need_line_decision_id
  )
  where current_confirmed_need_line_decision_id is not null;

create function atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'Confirmed Need line decisions cannot be deleted';
  end if;

  raise exception using
    errcode = '23514',
    message = 'Confirmed Need line decisions are immutable';
end;
$$;

create function atlas_planning.pa_06e_h1b1_confirmed_need_line_pointer_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_old_decision atlas_planning.confirmed_need_line_decisions%rowtype;
  v_new_decision atlas_planning.confirmed_need_line_decisions%rowtype;
begin
  if tg_op = 'INSERT' then
    if new.current_confirmed_need_line_decision_id is null then
      return new;
    end if;

    raise exception using
      errcode = '23514',
      message = 'New Confirmed Need lines must begin without decision authority';
  end if;

  if new.current_confirmed_need_line_decision_id
      is not distinct from old.current_confirmed_need_line_decision_id
  then
    return new;
  end if;

  if new.current_confirmed_need_line_decision_id is null then
    raise exception using
      errcode = '23514',
      message = 'Confirmed Need line decision authority cannot be cleared';
  end if;

  select decision.*
  into v_new_decision
  from atlas_planning.confirmed_need_line_decisions as decision
  where decision.confirmed_need_line_decision_id
      = new.current_confirmed_need_line_decision_id
    and decision.confirmed_need_line_id = new.confirmed_need_line_id;

  if v_new_decision.confirmed_need_line_decision_id is null then
    raise exception using
      errcode = '23514',
      message = 'The current decision must belong to the same Confirmed Need line';
  end if;

  if old.current_confirmed_need_line_decision_id is null then
    if v_new_decision.decision_number <> 1
      or v_new_decision.predecessor_decision_id is not null
    then
      raise exception using
        errcode = '23514',
        message = 'The first current decision must be line decision number one';
    end if;

    return new;
  end if;

  select decision.*
  into v_old_decision
  from atlas_planning.confirmed_need_line_decisions as decision
  where decision.confirmed_need_line_decision_id
      = old.current_confirmed_need_line_decision_id
    and decision.confirmed_need_line_id = old.confirmed_need_line_id;

  if v_old_decision.confirmed_need_line_decision_id is null
    or v_new_decision.predecessor_decision_id
      is distinct from v_old_decision.confirmed_need_line_decision_id
    or v_new_decision.decision_number <> v_old_decision.decision_number + 1
  then
    raise exception using
      errcode = '23514',
      message = 'The current decision may advance only to its direct successor';
  end if;

  return new;
end;
$$;

create function atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_line_ids uuid[];
  v_line_id uuid;
  v_line atlas_planning.confirmed_need_lines%rowtype;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_current_decision atlas_planning.confirmed_need_line_decisions%rowtype;
  v_decision_count bigint;
  v_min_decision_number bigint;
  v_max_decision_number bigint;
  v_eligible_policy_count bigint;
begin
  if tg_table_name = 'confirmed_need_lines' then
    if new.source_kind = 'WHOLESALE'
      or new.current_confirmed_need_line_decision_id is null
    then
      return new;
    end if;

    v_line_ids := array[new.confirmed_need_line_id];
  elsif tg_table_name = 'confirmed_need_line_revisions' then
    select
      line.source_kind,
      line.current_confirmed_need_line_decision_id
    into
      v_line.source_kind,
      v_line.current_confirmed_need_line_decision_id
    from atlas_planning.confirmed_need_lines as line
    where line.confirmed_need_line_id = new.confirmed_need_line_id;

    if v_line.source_kind = 'WHOLESALE'
      or v_line.current_confirmed_need_line_decision_id is null
    then
      return new;
    end if;

    v_line_ids := array[new.confirmed_need_line_id];
  elsif tg_table_name = 'planning_quantity_policy_revisions' then
    select array_agg(
      line.confirmed_need_line_id
      order by line.confirmed_need_line_id
    )
    into v_line_ids
    from atlas_planning.confirmed_need_lines as line
    where line.source_kind = 'NEED_GENERATION'
      and line.current_confirmed_need_line_decision_id is not null
      and line.controlled_unit_id = new.unit_id;

    if v_line_ids is null then
      return new;
    end if;
  else
    v_line_ids := array[new.confirmed_need_line_id];
  end if;

  foreach v_line_id in array v_line_ids
  loop
    select line.*
    into strict v_line
    from atlas_planning.confirmed_need_lines as line
    where line.confirmed_need_line_id = v_line_id
    for update;

    if v_line.source_kind = 'WHOLESALE' then
      continue;
    end if;

    select batch.*
    into strict v_batch
    from atlas_planning.confirmed_need_batches as batch
    where batch.confirmed_need_batch_id = v_line.confirmed_need_batch_id;

    if v_line.current_confirmed_need_line_decision_id is null then
      if exists (
        select 1
        from atlas_planning.confirmed_need_line_decisions as decision
        where decision.confirmed_need_line_id = v_line_id
      ) then
        raise exception using
          errcode = '23514',
          message = 'Every Confirmed Need line decision must become current atomically';
      end if;

      continue;
    end if;

    select decision.*
    into v_current_decision
    from atlas_planning.confirmed_need_line_decisions as decision
    where decision.confirmed_need_line_decision_id
        = v_line.current_confirmed_need_line_decision_id
      and decision.confirmed_need_line_id = v_line_id;

    if v_current_decision.confirmed_need_line_decision_id is null then
      raise exception using
        errcode = '23514',
        message = 'The current Confirmed Need line decision is missing or cross-line';
    end if;

    select
      count(*),
      min(decision.decision_number),
      max(decision.decision_number)
    into
      v_decision_count,
      v_min_decision_number,
      v_max_decision_number
    from atlas_planning.confirmed_need_line_decisions as decision
    where decision.confirmed_need_line_id = v_line_id;

    if v_min_decision_number <> 1
      or v_max_decision_number <> v_decision_count
      or v_current_decision.decision_number <> v_max_decision_number
      or exists (
        select 1
        from atlas_planning.confirmed_need_line_decisions as decision
        where decision.confirmed_need_line_id = v_line_id
          and decision.decision_number > 1
          and not exists (
            select 1
            from atlas_planning.confirmed_need_line_decisions as predecessor
            where predecessor.confirmed_need_line_id
                = decision.confirmed_need_line_id
              and predecessor.confirmed_need_line_decision_id
                = decision.predecessor_decision_id
              and predecessor.decision_number = decision.decision_number - 1
          )
      )
    then
      raise exception using
        errcode = '23514',
        message = 'Confirmed Need line decisions must form one contiguous direct chain';
    end if;

    if v_current_decision.confirmed_need_batch_id
        is distinct from v_line.confirmed_need_batch_id
      or v_current_decision.source_kind <> 'NEED_GENERATION'
      or v_current_decision.service_date is distinct from v_line.service_date
      or v_current_decision.customer_id is distinct from v_line.customer_id
      or v_current_decision.school_id is distinct from v_line.school_id
      or v_current_decision.delivery_location_id
        is distinct from v_line.delivery_location_id
      or v_current_decision.ingredient_id is distinct from v_line.ingredient_id
      or v_current_decision.unit_id is distinct from v_line.controlled_unit_id
      or not exists (
        select 1
        from atlas_planning.confirmed_need_line_revisions as revision
        where revision.confirmed_need_line_revision_id
            = v_current_decision.confirmed_need_line_revision_id
          and revision.confirmed_need_line_id = v_line_id
          and revision.is_current
      )
    then
      raise exception using
        errcode = '23514',
        message = 'The current decision must bind the exact current line revision and identity';
    end if;

    if tg_table_name = 'confirmed_need_line_decisions'
      and tg_op = 'INSERT'
    then
      if new.confirmed_need_line_decision_id
          = v_line.current_confirmed_need_line_decision_id
        and new.confirmed_need_batch_version <> v_batch.version
      then
        raise exception using
          errcode = '23514',
          message = 'A newly current decision must record the final Confirmed Need batch version';
      end if;
    end if;

    if exists (
      select 1
      from atlas_planning.confirmed_need_line_decisions as decision
      join atlas_planning.confirmed_need_line_revisions as revision
        on revision.confirmed_need_line_revision_id
          = decision.confirmed_need_line_revision_id
        and revision.confirmed_need_line_id = decision.confirmed_need_line_id
      join atlas_core.command_receipts as receipt
        on receipt.command_id = decision.command_id
      join atlas_planning.planning_quantity_policy_revisions as policy_revision
        on policy_revision.planning_quantity_policy_id
          = decision.planning_quantity_policy_id
        and policy_revision.planning_quantity_policy_revision_id
          = decision.planning_quantity_policy_revision_id
        and policy_revision.unit_id = decision.unit_id
      left join atlas_planning.confirmed_need_line_revisions as predecessor_revision
        on predecessor_revision.confirmed_need_line_revision_id
          = revision.predecessor_revision_id
        and predecessor_revision.confirmed_need_line_id
          = revision.confirmed_need_line_id
      where decision.confirmed_need_line_id = v_line_id
        and (
          decision.confirmed_need_batch_version > v_batch.version
          or receipt.outcome <> 'COMPLETED'
          or receipt.actor_id <> decision.decided_by_actor_id
          or revision.confirmed_need_batch_id
            is distinct from decision.confirmed_need_batch_id
          or revision.source_kind <> 'NEED_GENERATION'
          or revision.service_date is distinct from decision.service_date
          or revision.customer_id is distinct from decision.customer_id
          or revision.school_id is distinct from decision.school_id
          or revision.delivery_location_id
            is distinct from decision.delivery_location_id
          or revision.ingredient_id is distinct from decision.ingredient_id
          or revision.unit_id is distinct from decision.unit_id
          or decision.theoretical_quantity_before
            is distinct from revision.theoretical_quantity
          or mod(
            decision.confirmed_quantity_after,
            policy_revision.planning_step
          ) <> 0
          or decision.confirmed_quantity_after
            <> decision.planning_tick_count * policy_revision.planning_step
          or (
            decision.decision_kind = 'UNCHANGED_PROPOSAL_ACCEPTED'
            and (
              decision.proposed_quantity_before
                is distinct from revision.confirmed_quantity
              or decision.confirmed_quantity_after
                is distinct from revision.confirmed_quantity
              or exists (
                select 1
                from atlas_planning.confirmed_need_line_revisions
                  as command_revision
                where command_revision.confirmed_need_line_id
                    = decision.confirmed_need_line_id
                  and command_revision.command_id = decision.command_id
              )
            )
          )
          or (
            decision.decision_kind = 'ADJUSTED_QUANTITY_CONFIRMED'
            and (
              predecessor_revision.confirmed_need_line_revision_id is null
              or revision.revision_number
                <> predecessor_revision.revision_number + 1
              or revision.command_id is distinct from decision.command_id
              or decision.proposed_quantity_before
                is distinct from predecessor_revision.confirmed_quantity
              or decision.confirmed_quantity_after
                is distinct from revision.confirmed_quantity
              or row(
                revision.confirmed_need_batch_id,
                revision.source_kind,
                revision.need_generation_run_id,
                revision.need_generation_run_version,
                revision.need_generation_release_snapshot_id,
                revision.service_date,
                revision.customer_id,
                revision.school_id,
                revision.delivery_location_id,
                revision.ingredient_id,
                revision.unit_id,
                revision.theoretical_quantity
              ) is distinct from row(
                predecessor_revision.confirmed_need_batch_id,
                predecessor_revision.source_kind,
                predecessor_revision.need_generation_run_id,
                predecessor_revision.need_generation_run_version,
                predecessor_revision.need_generation_release_snapshot_id,
                predecessor_revision.service_date,
                predecessor_revision.customer_id,
                predecessor_revision.school_id,
                predecessor_revision.delivery_location_id,
                predecessor_revision.ingredient_id,
                predecessor_revision.unit_id,
                predecessor_revision.theoretical_quantity
              )
              or exists (
                (
                  select
                    contribution.need_generation_run_id,
                    contribution.need_generation_run_version,
                    contribution.need_generation_release_snapshot_id,
                    contribution.need_generation_release_snapshot_line_id,
                    contribution.theoretical_need_line_id,
                    contribution.service_date,
                    contribution.customer_id,
                    contribution.school_id,
                    contribution.delivery_location_id,
                    contribution.ingredient_id,
                    contribution.source_unit_id,
                    contribution.controlled_unit_id,
                    contribution.source_theoretical_quantity,
                    contribution.controlled_contribution_quantity
                  from
                    atlas_planning.confirmed_need_line_revision_contributions
                      as contribution
                  where contribution.confirmed_need_line_revision_id
                    = predecessor_revision.confirmed_need_line_revision_id
                  except all
                  select
                    contribution.need_generation_run_id,
                    contribution.need_generation_run_version,
                    contribution.need_generation_release_snapshot_id,
                    contribution.need_generation_release_snapshot_line_id,
                    contribution.theoretical_need_line_id,
                    contribution.service_date,
                    contribution.customer_id,
                    contribution.school_id,
                    contribution.delivery_location_id,
                    contribution.ingredient_id,
                    contribution.source_unit_id,
                    contribution.controlled_unit_id,
                    contribution.source_theoretical_quantity,
                    contribution.controlled_contribution_quantity
                  from
                    atlas_planning.confirmed_need_line_revision_contributions
                      as contribution
                  where contribution.confirmed_need_line_revision_id
                    = revision.confirmed_need_line_revision_id
                )
                union all
                (
                  select
                    contribution.need_generation_run_id,
                    contribution.need_generation_run_version,
                    contribution.need_generation_release_snapshot_id,
                    contribution.need_generation_release_snapshot_line_id,
                    contribution.theoretical_need_line_id,
                    contribution.service_date,
                    contribution.customer_id,
                    contribution.school_id,
                    contribution.delivery_location_id,
                    contribution.ingredient_id,
                    contribution.source_unit_id,
                    contribution.controlled_unit_id,
                    contribution.source_theoretical_quantity,
                    contribution.controlled_contribution_quantity
                  from
                    atlas_planning.confirmed_need_line_revision_contributions
                      as contribution
                  where contribution.confirmed_need_line_revision_id
                    = revision.confirmed_need_line_revision_id
                  except all
                  select
                    contribution.need_generation_run_id,
                    contribution.need_generation_run_version,
                    contribution.need_generation_release_snapshot_id,
                    contribution.need_generation_release_snapshot_line_id,
                    contribution.theoretical_need_line_id,
                    contribution.service_date,
                    contribution.customer_id,
                    contribution.school_id,
                    contribution.delivery_location_id,
                    contribution.ingredient_id,
                    contribution.source_unit_id,
                    contribution.controlled_unit_id,
                    contribution.source_theoretical_quantity,
                    contribution.controlled_contribution_quantity
                  from
                    atlas_planning.confirmed_need_line_revision_contributions
                      as contribution
                  where contribution.confirmed_need_line_revision_id
                    = predecessor_revision.confirmed_need_line_revision_id
                )
              )
              or (
                select count(*)
                from atlas_planning.confirmed_need_line_revisions
                  as command_revision
                where command_revision.confirmed_need_line_id
                    = decision.confirmed_need_line_id
                  and command_revision.command_id = decision.command_id
              ) <> 1
            )
          )
        )
    ) then
      raise exception using
        errcode = '23514',
        message = 'Confirmed Need decision revision, quantity, tick, actor, or command evidence is invalid';
    end if;

    for v_current_decision in
      select decision.*
      from atlas_planning.confirmed_need_line_decisions as decision
      where decision.confirmed_need_line_id = v_line_id
    loop
      select count(*)
      into v_eligible_policy_count
      from atlas_planning.planning_quantity_policy_revisions as eligible
      where eligible.unit_id = v_current_decision.unit_id
        and eligible.policy_revision_status in ('ACTIVE', 'RETIRED')
        and eligible.effective_from <= v_current_decision.service_date
        and (
          eligible.effective_to is null
          or v_current_decision.service_date < eligible.effective_to
        );

      if v_eligible_policy_count <> 1
        or not exists (
          select 1
          from atlas_planning.planning_quantity_policy_revisions as eligible
          where eligible.planning_quantity_policy_id
              = v_current_decision.planning_quantity_policy_id
            and eligible.planning_quantity_policy_revision_id
              = v_current_decision.planning_quantity_policy_revision_id
            and eligible.unit_id = v_current_decision.unit_id
            and eligible.policy_revision_status in ('ACTIVE', 'RETIRED')
            and eligible.effective_from <= v_current_decision.service_date
            and (
              eligible.effective_to is null
              or v_current_decision.service_date < eligible.effective_to
            )
        )
      then
        raise exception using
          errcode = '23514',
          message = 'Each decision must bind the sole eligible exact-Unit policy revision';
      end if;
    end loop;
  end loop;

  return new;
end;
$$;

create trigger confirmed_need_line_decisions_h1b1_guard
before update or delete
on atlas_planning.confirmed_need_line_decisions
for each row
execute function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_guard();

create trigger confirmed_need_lines_h1b1_pointer_guard
before insert or update of current_confirmed_need_line_decision_id
on atlas_planning.confirmed_need_lines
for each row
execute function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_pointer_guard();

create constraint trigger confirmed_need_line_decisions_h1b1_integrity
after insert or update
on atlas_planning.confirmed_need_line_decisions
deferrable initially deferred
for each row
execute function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity();

create constraint trigger confirmed_need_lines_h1b1_decision_integrity
after insert or update
on atlas_planning.confirmed_need_lines
deferrable initially deferred
for each row
execute function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity();

create constraint trigger confirmed_need_line_revisions_h1b1_decision_integrity
after insert or update
on atlas_planning.confirmed_need_line_revisions
deferrable initially deferred
for each row
execute function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity();

create constraint trigger confirmed_need_line_decisions_h1b1_policy_integrity
after insert or update
on atlas_planning.planning_quantity_policy_revisions
deferrable initially deferred
for each row
execute function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity();

alter table atlas_planning.confirmed_need_line_decisions
  enable row level security;
alter table atlas_planning.confirmed_need_line_decisions
  force row level security;

revoke all on table atlas_planning.confirmed_need_line_decisions
  from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_planning_materialization_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;

revoke all on function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_guard()
  from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_planning_materialization_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;
revoke all on function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_pointer_guard()
  from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_planning_materialization_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;
revoke all on function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity()
  from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_planning_materialization_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;

comment on table atlas_planning.confirmed_need_line_decisions is
  'Append-only policy-bound Planning authority for one exact Confirmed Need line revision.';
comment on column
  atlas_planning.confirmed_need_lines.current_confirmed_need_line_decision_id
  is 'Nullable monotonic pointer to the line current append-only Planning decision.';

reset role;
