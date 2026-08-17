-- PLANNING-CONTRACT-02B: preserve unaffected Confirmed Need decisions.
--
-- Human decisions remain append-only human evidence. This migration adds
-- separate immutable system evidence that either carries the current decision
-- across one direct generated successor, or explains why that authority was
-- invalidated.

reset role;
grant atlas_planning_materialization_runtime,
  atlas_confirmed_need_review_runtime,
  atlas_need_generation_runtime
to postgres with set true;
set role atlas_owner;

grant create on schema atlas_core
to atlas_planning_materialization_runtime,
  atlas_confirmed_need_review_runtime;

create table atlas_planning.confirmed_need_line_decision_continuity (
  confirmed_need_line_decision_continuity_id uuid not null
    default gen_random_uuid(),
  confirmed_need_batch_id uuid not null,
  confirmed_need_line_id uuid not null,
  source_confirmed_need_line_decision_id uuid not null,
  predecessor_confirmed_need_line_revision_id uuid not null,
  successor_confirmed_need_line_revision_id uuid,
  predecessor_need_generation_run_id uuid not null,
  predecessor_need_generation_run_version bigint not null,
  predecessor_need_generation_release_snapshot_id uuid not null,
  successor_need_generation_run_id uuid not null,
  successor_need_generation_run_version bigint not null,
  successor_need_generation_release_snapshot_id uuid not null,
  source_kind text not null default 'NEED_GENERATION',
  service_date date not null,
  customer_id uuid not null,
  school_id uuid not null,
  delivery_location_id uuid not null,
  ingredient_id uuid not null,
  unit_id uuid not null,
  continuity_kind text not null,
  command_id uuid not null,
  initiated_by_actor_id uuid not null,
  recorded_at timestamptz not null default pg_catalog.transaction_timestamp(),
  constraint confirmed_need_line_decision_continuity_pkey primary key (
    confirmed_need_line_decision_continuity_id
  ),
  constraint confirmed_need_line_decision_continuity_command_line_key unique (
    command_id,
    confirmed_need_line_id
  ),
  constraint confirmed_need_line_decision_continuity_direct_context_key unique (
    confirmed_need_line_id,
    predecessor_confirmed_need_line_revision_id,
    successor_need_generation_run_id,
    successor_need_generation_run_version
  ),
  constraint confirmed_need_line_decision_continuity_source_check check (
    source_kind = 'NEED_GENERATION'
  ),
  constraint confirmed_need_line_decision_continuity_kind_check check (
    continuity_kind in (
      'CARRIED_FORWARD',
      'INVALIDATED_PROPOSAL_CHANGE',
      'INVALIDATED_POLICY_INCOMPATIBLE',
      'INVALIDATED_LINE_REMOVED'
    )
  ),
  constraint confirmed_need_line_decision_continuity_shape_check check (
    (
      continuity_kind = 'INVALIDATED_LINE_REMOVED'
      and successor_confirmed_need_line_revision_id is null
    )
    or (
      continuity_kind <> 'INVALIDATED_LINE_REMOVED'
      and successor_confirmed_need_line_revision_id is not null
    )
  ),
  constraint confirmed_need_line_decision_continuity_version_check check (
    predecessor_need_generation_run_version > 0
    and successor_need_generation_run_version > 0
  ),
  constraint confirmed_need_line_decision_continuity_line_fkey foreign key (
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
  constraint confirmed_need_line_decision_continuity_decision_fkey foreign key (
    confirmed_need_line_id,
    source_confirmed_need_line_decision_id
  ) references atlas_planning.confirmed_need_line_decisions (
    confirmed_need_line_id,
    confirmed_need_line_decision_id
  ) on delete restrict,
  constraint confirmed_need_line_decision_continuity_predecessor_fkey foreign key (
    predecessor_confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    predecessor_need_generation_run_id,
    predecessor_need_generation_run_version,
    predecessor_need_generation_release_snapshot_id,
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
    need_generation_run_id,
    need_generation_run_version,
    need_generation_release_snapshot_id,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id
  ) on delete restrict,
  constraint confirmed_need_line_decision_continuity_successor_fkey foreign key (
    successor_confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    successor_need_generation_run_id,
    successor_need_generation_run_version,
    successor_need_generation_release_snapshot_id,
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
    need_generation_run_id,
    need_generation_run_version,
    need_generation_release_snapshot_id,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id
  ) on delete restrict,
  constraint cn_decision_continuity_predecessor_release_fkey
    foreign key (
      predecessor_need_generation_release_snapshot_id,
      predecessor_need_generation_run_id,
      predecessor_need_generation_run_version
    ) references atlas_planning.need_generation_release_snapshots (
      need_generation_release_snapshot_id,
      need_generation_run_id,
      released_run_version
    ) on delete restrict,
  constraint cn_decision_continuity_successor_release_fkey
    foreign key (
      successor_need_generation_release_snapshot_id,
      successor_need_generation_run_id,
      successor_need_generation_run_version
    ) references atlas_planning.need_generation_release_snapshots (
      need_generation_release_snapshot_id,
      need_generation_run_id,
      released_run_version
    ) on delete restrict,
  constraint confirmed_need_line_decision_continuity_command_fkey foreign key (
    command_id
  ) references atlas_core.command_receipts (command_id) on delete restrict,
  constraint confirmed_need_line_decision_continuity_actor_fkey foreign key (
    initiated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict
);

create index confirmed_need_line_decision_continuity_decision_idx
  on atlas_planning.confirmed_need_line_decision_continuity (
    source_confirmed_need_line_decision_id,
    confirmed_need_line_id
  );
create index confirmed_need_line_decision_continuity_successor_idx
  on atlas_planning.confirmed_need_line_decision_continuity (
    successor_confirmed_need_line_revision_id
  ) where successor_confirmed_need_line_revision_id is not null;
create index confirmed_need_line_decision_continuity_batch_context_idx
  on atlas_planning.confirmed_need_line_decision_continuity (
    confirmed_need_batch_id,
    successor_need_generation_run_id,
    successor_need_generation_run_version,
    continuity_kind
  );

create function atlas_core.planning_contract_02b_decision_authorizes_revision(
  p_decision_id uuid,
  p_line_id uuid,
  p_revision_id uuid
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_line_decision_id = p_decision_id
      and decision.confirmed_need_line_id = p_line_id
      and (
        decision.confirmed_need_line_revision_id = p_revision_id
        or exists (
          select 1
          from atlas_planning.confirmed_need_line_decision_continuity continuity
          where continuity.confirmed_need_line_id = p_line_id
            and continuity.source_confirmed_need_line_decision_id = p_decision_id
            and continuity.successor_confirmed_need_line_revision_id = p_revision_id
            and continuity.continuity_kind = 'CARRIED_FORWARD'
        )
      )
  );
$$;

create function atlas_core.planning_contract_02b_invalidation_authorizes_clear(
  p_line_id uuid,
  p_decision_id uuid
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_planning.confirmed_need_line_decision_continuity continuity
    where continuity.confirmed_need_line_id = p_line_id
      and continuity.source_confirmed_need_line_decision_id = p_decision_id
      and continuity.continuity_kind in (
        'INVALIDATED_PROPOSAL_CHANGE',
        'INVALIDATED_POLICY_INCOMPATIBLE'
      )
      and exists (
        select 1
        from atlas_planning.confirmed_need_line_revisions revision
        where revision.confirmed_need_line_revision_id =
            continuity.successor_confirmed_need_line_revision_id
          and revision.confirmed_need_line_id = p_line_id
          and revision.is_current
      )
    union all
    select 1
    from atlas_planning.confirmed_need_line_decision_continuity continuity
    where continuity.confirmed_need_line_id = p_line_id
      and continuity.source_confirmed_need_line_decision_id = p_decision_id
      and continuity.continuity_kind = 'INVALIDATED_LINE_REMOVED'
      and not exists (
        select 1
        from atlas_planning.confirmed_need_line_revisions revision
        where revision.confirmed_need_line_id = p_line_id
          and revision.is_current
      )
  );
$$;

create function atlas_core.planning_contract_02b_policy_incompatible_batch(
  p_need_generation_run_id uuid,
  p_period_start date,
  p_period_end date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_planning.confirmed_need_batches batch
    join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_batch_id = batch.confirmed_need_batch_id
    join atlas_planning.confirmed_need_line_decisions decision
      on decision.confirmed_need_line_decision_id =
        line.current_confirmed_need_line_decision_id
    where batch.source_kind = 'NEED_GENERATION'
      and (
        (
          p_need_generation_run_id is not null
          and (
            batch.current_need_generation_run_id = p_need_generation_run_id
            or exists (
              select 1
              from atlas_planning.need_generation_runs target_run
              where target_run.need_generation_run_id =
                  p_need_generation_run_id
                and target_run.period_start = batch.period_start
                and target_run.period_end = batch.period_end
            )
          )
        )
        or (
          p_need_generation_run_id is null
          and batch.period_start = p_period_start
          and batch.period_end = p_period_end
        )
      )
      and (
        (
          select count(*)
          from atlas_planning.planning_quantity_policy_revisions eligible
          where eligible.unit_id = decision.unit_id
            and eligible.policy_revision_status in ('ACTIVE', 'RETIRED')
            and eligible.effective_from <= decision.service_date
            and (
              eligible.effective_to is null
              or decision.service_date < eligible.effective_to
            )
        ) <> 1
        or not exists (
          select 1
          from atlas_planning.planning_quantity_policy_revisions eligible
          where eligible.planning_quantity_policy_id =
              decision.planning_quantity_policy_id
            and eligible.planning_quantity_policy_revision_id =
              decision.planning_quantity_policy_revision_id
            and eligible.unit_id = decision.unit_id
            and eligible.policy_revision_status in ('ACTIVE', 'RETIRED')
            and eligible.effective_from <= decision.service_date
            and (
              eligible.effective_to is null
              or decision.service_date < eligible.effective_to
            )
        )
      )
  );
$$;

create function atlas_planning.planning_contract_02b_continuity_immutable()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Confirmed Need decision continuity evidence is immutable and undeletable';
end;
$$;

create function atlas_planning.planning_contract_02b_continuity_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_line atlas_planning.confirmed_need_lines%rowtype;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_decision atlas_planning.confirmed_need_line_decisions%rowtype;
  v_predecessor atlas_planning.confirmed_need_line_revisions%rowtype;
  v_successor atlas_planning.confirmed_need_line_revisions%rowtype;
  v_successor_run atlas_planning.need_generation_runs%rowtype;
  v_policy_count integer;
  v_policy_revision_id uuid;
  v_receipt atlas_core.command_receipts%rowtype;
begin
  select * into strict v_line
  from atlas_planning.confirmed_need_lines line
  where line.confirmed_need_line_id = new.confirmed_need_line_id;
  select * into strict v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = new.confirmed_need_batch_id;
  select * into strict v_decision
  from atlas_planning.confirmed_need_line_decisions decision
  where decision.confirmed_need_line_decision_id =
      new.source_confirmed_need_line_decision_id
    and decision.confirmed_need_line_id = new.confirmed_need_line_id;
  select * into strict v_predecessor
  from atlas_planning.confirmed_need_line_revisions revision
  where revision.confirmed_need_line_revision_id =
      new.predecessor_confirmed_need_line_revision_id;
  select * into strict v_receipt
  from atlas_core.command_receipts receipt
  where receipt.command_id = new.command_id;
  select * into strict v_successor_run
  from atlas_planning.need_generation_runs run
  where run.need_generation_run_id = new.successor_need_generation_run_id;

  if v_receipt.actor_id is distinct from new.initiated_by_actor_id
    or v_receipt.outcome <> 'COMPLETED'
    or v_batch.current_need_generation_run_id is distinct from
      new.successor_need_generation_run_id
    or v_batch.current_need_generation_run_version is distinct from
      new.successor_need_generation_run_version
    or v_batch.current_need_generation_release_snapshot_id is distinct from
      new.successor_need_generation_release_snapshot_id
    or v_successor_run.predecessor_need_generation_run_id is distinct from
      new.predecessor_need_generation_run_id
    or v_successor_run.version is distinct from
      new.successor_need_generation_run_version
    or v_successor_run.run_status <> 'RELEASED_FOR_CONFIRMATION'
    or not atlas_core.planning_contract_02b_decision_authorizes_revision(
      v_decision.confirmed_need_line_decision_id,
      v_line.confirmed_need_line_id,
      v_predecessor.confirmed_need_line_revision_id
    )
  then
    raise exception using
      errcode = '23514',
      message = 'Decision continuity does not bind the direct authoritative predecessor context';
  end if;

  if new.successor_confirmed_need_line_revision_id is not null then
    select * into strict v_successor
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_line_revision_id =
        new.successor_confirmed_need_line_revision_id;
    if not v_successor.is_current
      or v_successor.predecessor_revision_id is distinct from
        v_predecessor.confirmed_need_line_revision_id
    then
      raise exception using
        errcode = '23514',
        message = 'Decision continuity successor is not the direct current revision';
    end if;
  elsif exists (
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_line_id = new.confirmed_need_line_id
      and revision.is_current
  ) then
    raise exception using
      errcode = '23514',
      message = 'A removed-line invalidation cannot retain a current revision';
  end if;

  select count(*)::integer,
    (array_agg(policy.planning_quantity_policy_revision_id
      order by policy.effective_from desc,
        policy.planning_quantity_policy_revision_id))[1]
  into v_policy_count, v_policy_revision_id
  from atlas_planning.planning_quantity_policy_revisions policy
  where policy.unit_id = v_line.controlled_unit_id
    and policy.policy_revision_status in ('ACTIVE', 'RETIRED')
    and policy.effective_from <= v_line.service_date
    and (policy.effective_to is null
      or v_line.service_date < policy.effective_to);

  if new.continuity_kind = 'CARRIED_FORWARD' then
    if v_line.current_confirmed_need_line_decision_id is distinct from
        v_decision.confirmed_need_line_decision_id
      or v_successor.theoretical_quantity is distinct from
        v_predecessor.theoretical_quantity
      or v_successor.confirmed_quantity is distinct from
        v_decision.confirmed_quantity_after
      or v_policy_count <> 1
      or v_policy_revision_id is distinct from
        v_decision.planning_quantity_policy_revision_id
    then
      raise exception using
        errcode = '23514',
        message = 'Carried authority requires identical proposal and exact effective policy';
    end if;
  elsif new.continuity_kind = 'INVALIDATED_PROPOSAL_CHANGE' then
    if v_line.current_confirmed_need_line_decision_id is not null
      or v_successor.theoretical_quantity is not distinct from
        v_predecessor.theoretical_quantity
    then
      raise exception using
        errcode = '23514',
        message = 'Proposal invalidation requires one exact changed successor and cleared authority';
    end if;
  elsif new.continuity_kind = 'INVALIDATED_POLICY_INCOMPATIBLE' then
    if v_line.current_confirmed_need_line_decision_id is not null
      or v_successor.theoretical_quantity is distinct from
        v_predecessor.theoretical_quantity
      or (v_policy_count = 1 and v_policy_revision_id is not distinct from
        v_decision.planning_quantity_policy_revision_id)
    then
      raise exception using
        errcode = '23514',
        message = 'Policy invalidation requires an unchanged proposal and incompatible effective policy';
    end if;
  elsif v_line.current_confirmed_need_line_decision_id is not null then
    raise exception using
      errcode = '23514',
      message = 'Removed-line invalidation requires cleared decision authority';
  end if;

  return null;
end;
$$;

create trigger confirmed_need_line_decision_continuity_immutable
before update or delete
on atlas_planning.confirmed_need_line_decision_continuity
for each row execute function
  atlas_planning.planning_contract_02b_continuity_immutable();

create constraint trigger confirmed_need_line_decision_continuity_integrity
after insert
on atlas_planning.confirmed_need_line_decision_continuity
deferrable initially deferred
for each row execute function
  atlas_planning.planning_contract_02b_continuity_integrity();

create function atlas_planning.planning_contract_02b_continue_human_chain()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_latest atlas_planning.confirmed_need_line_decisions%rowtype;
begin
  if new.decision_number <> 1 or new.predecessor_decision_id is not null then
    return new;
  end if;

  select decision.* into v_latest
  from atlas_planning.confirmed_need_line_decisions decision
  where decision.confirmed_need_line_id = new.confirmed_need_line_id
  order by decision.decision_number desc
  limit 1;

  if v_latest.confirmed_need_line_decision_id is null then
    return new;
  end if;

  if not exists (
    select 1
    from atlas_planning.confirmed_need_line_decision_continuity continuity
    where continuity.confirmed_need_line_id = new.confirmed_need_line_id
      and continuity.source_confirmed_need_line_decision_id =
        v_latest.confirmed_need_line_decision_id
      and continuity.continuity_kind in (
        'INVALIDATED_PROPOSAL_CHANGE',
        'INVALIDATED_POLICY_INCOMPATIBLE',
        'INVALIDATED_LINE_REMOVED'
      )
  ) then
    return new;
  end if;

  new.decision_number := v_latest.decision_number + 1;
  new.predecessor_decision_id := v_latest.confirmed_need_line_decision_id;
  return new;
end;
$$;

create trigger confirmed_need_line_decisions_02b_continue_chain
before insert on atlas_planning.confirmed_need_line_decisions
for each row execute function
  atlas_planning.planning_contract_02b_continue_human_chain();

create or replace function
  atlas_planning.pa_06e_h1b1_confirmed_need_line_pointer_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_old_decision atlas_planning.confirmed_need_line_decisions%rowtype;
  v_new_decision atlas_planning.confirmed_need_line_decisions%rowtype;
  v_latest_decision atlas_planning.confirmed_need_line_decisions%rowtype;
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
    if old.current_confirmed_need_line_decision_id is null
      or not atlas_core.planning_contract_02b_invalidation_authorizes_clear(
        old.confirmed_need_line_id,
        old.current_confirmed_need_line_decision_id
      )
    then
      raise exception using
        errcode = '23514',
        message = 'Decision authority may be cleared only by exact immutable invalidation evidence';
    end if;
    return new;
  end if;

  select decision.* into v_new_decision
  from atlas_planning.confirmed_need_line_decisions decision
  where decision.confirmed_need_line_decision_id =
      new.current_confirmed_need_line_decision_id
    and decision.confirmed_need_line_id = new.confirmed_need_line_id;
  if v_new_decision.confirmed_need_line_decision_id is null then
    raise exception using
      errcode = '23514',
      message = 'The current decision must belong to the same Confirmed Need line';
  end if;

  if old.current_confirmed_need_line_decision_id is null then
    select decision.* into v_latest_decision
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_line_id = new.confirmed_need_line_id
      and decision.confirmed_need_line_decision_id <>
        v_new_decision.confirmed_need_line_decision_id
    order by decision.decision_number desc
    limit 1;

    if v_latest_decision.confirmed_need_line_decision_id is null then
      if v_new_decision.decision_number <> 1
        or v_new_decision.predecessor_decision_id is not null
      then
        raise exception using
          errcode = '23514',
          message = 'The first current decision must be line decision number one';
      end if;
    elsif v_new_decision.decision_number <> v_latest_decision.decision_number + 1
      or v_new_decision.predecessor_decision_id is distinct from
        v_latest_decision.confirmed_need_line_decision_id
      or not exists (
        select 1
        from atlas_planning.confirmed_need_line_decision_continuity continuity
        where continuity.confirmed_need_line_id = new.confirmed_need_line_id
          and continuity.source_confirmed_need_line_decision_id =
            v_latest_decision.confirmed_need_line_decision_id
          and continuity.continuity_kind in (
            'INVALIDATED_PROPOSAL_CHANGE',
            'INVALIDATED_POLICY_INCOMPATIBLE',
            'INVALIDATED_LINE_REMOVED'
          )
      )
    then
      raise exception using
        errcode = '23514',
        message = 'Reconfirmation must directly continue the invalidated human decision chain';
    end if;
    return new;
  end if;

  select decision.* into v_old_decision
  from atlas_planning.confirmed_need_line_decisions decision
  where decision.confirmed_need_line_decision_id =
      old.current_confirmed_need_line_decision_id
    and decision.confirmed_need_line_id = old.confirmed_need_line_id;
  if v_old_decision.confirmed_need_line_decision_id is null
    or v_new_decision.predecessor_decision_id is distinct from
      v_old_decision.confirmed_need_line_decision_id
    or v_new_decision.decision_number <> v_old_decision.decision_number + 1
  then
    raise exception using
      errcode = '23514',
      message = 'The current decision may advance only to its direct successor';
  end if;
  return new;
end;
$$;

alter table atlas_planning.confirmed_need_line_decisions
  drop constraint confirmed_need_line_decisions_correction_note_check,
  add constraint confirmed_need_line_decisions_correction_note_check check (
    predecessor_decision_id is null
    or reason_note is not null
    or (
      decision_kind = 'UNCHANGED_PROPOSAL_ACCEPTED'
      and reason_code = 'PROPOSAL_ACCEPTED'
    )
  );

alter table atlas_planning.confirmed_need_line_decisions
  add constraint confirmed_need_line_decisions_continuity_validation_owner_key
  unique (
    confirmed_need_line_decision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id,
    confirmed_quantity_after,
    planning_tick_count
  );

alter table atlas_planning.confirmed_need_validation_lines
  drop constraint confirmed_need_validation_lines_decision_fkey,
  add constraint confirmed_need_validation_lines_decision_fkey foreign key (
    current_confirmed_need_line_decision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    controlled_unit_id,
    confirmed_quantity,
    planning_tick_count
  ) references atlas_planning.confirmed_need_line_decisions (
    confirmed_need_line_decision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id,
    confirmed_quantity_after,
    planning_tick_count
  ) on delete restrict;

create function atlas_core.planning_contract_02b_removed_business_fact_count(
  p_batch_id uuid,
  p_predecessor_run_id uuid,
  p_predecessor_run_version bigint,
  p_predecessor_release_id uuid,
  p_successor_run_id uuid,
  p_successor_run_version bigint,
  p_successor_release_id uuid
)
returns integer
language sql
stable
security invoker
set search_path = ''
as $$
  select count(distinct predecessor.confirmed_need_line_id)::integer
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_revisions predecessor
    on predecessor.confirmed_need_line_id = line.confirmed_need_line_id
   and predecessor.need_generation_run_id = p_predecessor_run_id
   and predecessor.need_generation_run_version = p_predecessor_run_version
   and predecessor.need_generation_release_snapshot_id =
     p_predecessor_release_id
  where line.confirmed_need_batch_id = p_batch_id
    and line.source_kind = 'NEED_GENERATION'
    and not exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions successor
      where successor.confirmed_need_line_id =
          predecessor.confirmed_need_line_id
        and successor.need_generation_run_id = p_successor_run_id
        and successor.need_generation_run_version = p_successor_run_version
        and successor.need_generation_release_snapshot_id =
          p_successor_release_id
        and successor.is_current
    );
$$;

create function atlas_core.planning_contract_02b_apply_decision_continuity(
  p_batch_id uuid,
  p_predecessor_run_id uuid,
  p_predecessor_run_version bigint,
  p_predecessor_release_id uuid,
  p_successor_run_id uuid,
  p_successor_run_version bigint,
  p_successor_release_id uuid,
  p_command_id uuid,
  p_actor_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_item record;
  v_successor atlas_planning.confirmed_need_line_revisions%rowtype;
  v_successor_count integer;
  v_policy_count integer;
  v_policy_revision_id uuid;
  v_kind text;
  v_carried integer := 0;
  v_changed integer := 0;
  v_removed integer := 0;
begin
  for v_item in
    select
      line.*,
      predecessor.confirmed_need_line_revision_id as predecessor_revision_id,
      predecessor.theoretical_quantity as predecessor_theoretical_quantity,
      decision.confirmed_need_line_decision_id as decision_id,
      decision.confirmed_quantity_after,
      decision.planning_quantity_policy_revision_id
    from atlas_planning.confirmed_need_lines line
    join atlas_planning.confirmed_need_line_revisions predecessor
      on predecessor.confirmed_need_line_id = line.confirmed_need_line_id
     and predecessor.need_generation_run_id = p_predecessor_run_id
     and predecessor.need_generation_run_version = p_predecessor_run_version
     and predecessor.need_generation_release_snapshot_id = p_predecessor_release_id
    join atlas_planning.confirmed_need_line_decisions decision
      on decision.confirmed_need_line_decision_id =
        line.current_confirmed_need_line_decision_id
     and decision.confirmed_need_line_id = line.confirmed_need_line_id
    where line.confirmed_need_batch_id = p_batch_id
      and line.source_kind = 'NEED_GENERATION'
      and atlas_core.planning_contract_02b_decision_authorizes_revision(
        decision.confirmed_need_line_decision_id,
        line.confirmed_need_line_id,
        predecessor.confirmed_need_line_revision_id
      )
    order by line.confirmed_need_line_id
  loop
    v_successor := null;
    select count(*)::integer into v_successor_count
    from atlas_planning.confirmed_need_line_revisions successor
    where successor.confirmed_need_line_id = v_item.confirmed_need_line_id
      and successor.need_generation_run_id = p_successor_run_id
      and successor.need_generation_run_version = p_successor_run_version
      and successor.need_generation_release_snapshot_id = p_successor_release_id
      and successor.is_current;
    if v_successor_count > 1 then
      raise exception using
        errcode = '23514',
        message = 'Decision continuity successor mapping is ambiguous';
    elsif v_successor_count = 1 then
      select * into strict v_successor
      from atlas_planning.confirmed_need_line_revisions successor
      where successor.confirmed_need_line_id = v_item.confirmed_need_line_id
        and successor.need_generation_run_id = p_successor_run_id
        and successor.need_generation_run_version = p_successor_run_version
        and successor.need_generation_release_snapshot_id = p_successor_release_id
        and successor.is_current;
    end if;

    if v_successor_count = 0 then
      v_kind := 'INVALIDATED_LINE_REMOVED';
      v_removed := v_removed + 1;
    elsif v_successor.theoretical_quantity is distinct from
        v_item.predecessor_theoretical_quantity
    then
      v_kind := 'INVALIDATED_PROPOSAL_CHANGE';
      v_changed := v_changed + 1;
    else
      select count(*)::integer,
        (array_agg(policy.planning_quantity_policy_revision_id
          order by policy.effective_from desc,
            policy.planning_quantity_policy_revision_id))[1]
      into v_policy_count, v_policy_revision_id
      from atlas_planning.planning_quantity_policy_revisions policy
      where policy.unit_id = v_item.controlled_unit_id
        and policy.policy_revision_status in ('ACTIVE', 'RETIRED')
        and policy.effective_from <= v_item.service_date
        and (policy.effective_to is null
          or v_item.service_date < policy.effective_to);

      if v_policy_count = 1 and v_policy_revision_id is not distinct from
          v_item.planning_quantity_policy_revision_id
      then
        v_kind := 'CARRIED_FORWARD';
        update atlas_planning.confirmed_need_line_revisions
        set confirmed_quantity = v_item.confirmed_quantity_after
        where confirmed_need_line_revision_id =
          v_successor.confirmed_need_line_revision_id;
        v_carried := v_carried + 1;
      else
        v_kind := 'INVALIDATED_POLICY_INCOMPATIBLE';
        v_changed := v_changed + 1;
      end if;
    end if;

    insert into atlas_planning.confirmed_need_line_decision_continuity (
      confirmed_need_batch_id,
      confirmed_need_line_id,
      source_confirmed_need_line_decision_id,
      predecessor_confirmed_need_line_revision_id,
      successor_confirmed_need_line_revision_id,
      predecessor_need_generation_run_id,
      predecessor_need_generation_run_version,
      predecessor_need_generation_release_snapshot_id,
      successor_need_generation_run_id,
      successor_need_generation_run_version,
      successor_need_generation_release_snapshot_id,
      source_kind,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      unit_id,
      continuity_kind,
      command_id,
      initiated_by_actor_id
    ) values (
      p_batch_id,
      v_item.confirmed_need_line_id,
      v_item.decision_id,
      v_item.predecessor_revision_id,
      case when v_successor_count = 1
        then v_successor.confirmed_need_line_revision_id end,
      p_predecessor_run_id,
      p_predecessor_run_version,
      p_predecessor_release_id,
      p_successor_run_id,
      p_successor_run_version,
      p_successor_release_id,
      'NEED_GENERATION',
      v_item.service_date,
      v_item.customer_id,
      v_item.school_id,
      v_item.delivery_location_id,
      v_item.ingredient_id,
      v_item.controlled_unit_id,
      v_kind,
      p_command_id,
      p_actor_id
    );

    if v_kind <> 'CARRIED_FORWARD' then
      update atlas_planning.confirmed_need_lines
      set current_confirmed_need_line_decision_id = null
      where confirmed_need_line_id = v_item.confirmed_need_line_id;
    end if;
  end loop;

  return pg_catalog.jsonb_build_object(
    'carried_forward', v_carried,
    'changed', v_changed,
    'removed', v_removed
  );
end;
$$;

reset role;
alter function atlas_core.planning_contract_02b_apply_decision_continuity(
  uuid, uuid, bigint, uuid, uuid, bigint, uuid, uuid, uuid
) owner to atlas_planning_materialization_runtime;
alter function atlas_core.planning_contract_02b_policy_incompatible_batch(
  uuid, date, date
) owner to atlas_planning_materialization_runtime;
set role atlas_owner;

create function atlas_core.planning_contract_02b_extend_workbench(
  p_workbench jsonb
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    p_workbench ->> 'confirmed_need_batch_id'
  );
  v_lines jsonb;
  v_counts jsonb;
begin
  select coalesce(pg_catalog.jsonb_agg(
    item || pg_catalog.jsonb_build_object(
      'confirmation_state', case
        when line.current_confirmed_need_line_decision_id is not null
          and exists (
            select 1
            from atlas_planning.confirmed_need_line_decision_continuity c
            where c.confirmed_need_line_id = line.confirmed_need_line_id
              and c.source_confirmed_need_line_decision_id =
                line.current_confirmed_need_line_decision_id
              and c.successor_confirmed_need_line_revision_id =
                revision.confirmed_need_line_revision_id
              and c.continuity_kind = 'CARRIED_FORWARD'
          ) then 'CARRIED_FORWARD'
        when line.current_confirmed_need_line_decision_id is not null
          then 'CONFIRMED_CURRENT'
        when exists (
          select 1
          from atlas_planning.confirmed_need_line_decision_continuity c
          where c.confirmed_need_line_id = line.confirmed_need_line_id
            and c.successor_confirmed_need_line_revision_id =
              revision.confirmed_need_line_revision_id
            and c.continuity_kind in (
              'INVALIDATED_PROPOSAL_CHANGE',
              'INVALIDATED_POLICY_INCOMPATIBLE'
            )
          ) then 'CHANGED'
        when revision.revision_number = 1
          and not exists (
            select 1
            from atlas_planning.confirmed_need_line_decisions d
            where d.confirmed_need_line_id = line.confirmed_need_line_id
          ) then 'NEW'
        else 'UNREVIEWED'
      end
    ) order by ordinal
  ), '[]'::jsonb) into v_lines
  from pg_catalog.jsonb_array_elements(p_workbench -> 'lines')
    with ordinality page(item, ordinal)
  join atlas_planning.confirmed_need_lines line
    on line.confirmed_need_line_id =
      atlas_core.pa_05b_safe_uuid(item ->> 'confirmed_need_line_id')
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_id = line.confirmed_need_line_id
   and revision.is_current;

  with current_lines as (
    select line.*, revision.confirmed_need_line_revision_id,
      revision.revision_number
    from atlas_planning.confirmed_need_lines line
    join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_id = line.confirmed_need_line_id
     and revision.is_current
    where line.confirmed_need_batch_id = v_batch_id
      and line.source_kind = 'NEED_GENERATION'
  )
  select pg_catalog.jsonb_build_object(
    'carried_forward', count(*) filter (
      where line.current_confirmed_need_line_decision_id is not null
        and exists (
          select 1
          from atlas_planning.confirmed_need_line_decision_continuity c
          where c.confirmed_need_line_id = line.confirmed_need_line_id
            and c.source_confirmed_need_line_decision_id =
              line.current_confirmed_need_line_decision_id
            and c.successor_confirmed_need_line_revision_id =
              line.confirmed_need_line_revision_id
            and c.continuity_kind = 'CARRIED_FORWARD'
        )
    )::integer,
    'needs_review', count(*) filter (
      where line.current_confirmed_need_line_decision_id is null
    )::integer,
    'changed', count(*) filter (
      where line.current_confirmed_need_line_decision_id is null
        and exists (
          select 1
          from atlas_planning.confirmed_need_line_decision_continuity c
          where c.confirmed_need_line_id = line.confirmed_need_line_id
            and c.successor_confirmed_need_line_revision_id =
              line.confirmed_need_line_revision_id
            and c.continuity_kind in (
              'INVALIDATED_PROPOSAL_CHANGE',
              'INVALIDATED_POLICY_INCOMPATIBLE'
            )
        )
    )::integer,
    'new', count(*) filter (
      where line.current_confirmed_need_line_decision_id is null
        and line.revision_number = 1
        and not exists (
          select 1
          from atlas_planning.confirmed_need_line_decisions d
          where d.confirmed_need_line_id = line.confirmed_need_line_id
        )
    )::integer,
    'removed', coalesce((
      select atlas_core.planning_contract_02b_removed_business_fact_count(
        batch.confirmed_need_batch_id,
        predecessor_release.need_generation_run_id,
        predecessor_release.released_run_version,
        predecessor_release.need_generation_release_snapshot_id,
        batch.current_need_generation_run_id,
        batch.current_need_generation_run_version,
        batch.current_need_generation_release_snapshot_id
      )
      from atlas_planning.confirmed_need_batches batch
      join atlas_planning.need_generation_runs successor_run
        on successor_run.need_generation_run_id =
          batch.current_need_generation_run_id
      join atlas_planning.need_generation_release_snapshots predecessor_release
        on predecessor_release.need_generation_run_id =
          successor_run.predecessor_need_generation_run_id
      where batch.confirmed_need_batch_id = v_batch_id
        and batch.source_kind = 'NEED_GENERATION'
    ), 0)
  ) into v_counts
  from current_lines line;

  return p_workbench || pg_catalog.jsonb_build_object(
    'lines', v_lines,
    'line_counts', coalesce(p_workbench -> 'line_counts', '{}'::jsonb)
      || v_counts
  );
end;
$$;

alter table atlas_planning.confirmed_need_line_decision_continuity
  enable row level security;
alter table atlas_planning.confirmed_need_line_decision_continuity
  force row level security;

create policy planning_contract_02b_materialization_select
on atlas_planning.confirmed_need_line_decision_continuity
for select to atlas_planning_materialization_runtime
using (true);
create policy planning_contract_02b_materialization_insert
on atlas_planning.confirmed_need_line_decision_continuity
for insert to atlas_planning_materialization_runtime
with check (source_kind = 'NEED_GENERATION');
create policy planning_contract_02b_review_select
on atlas_planning.confirmed_need_line_decision_continuity
for select to atlas_confirmed_need_review_runtime
using (true);
create policy planning_contract_02b_generation_select
on atlas_planning.confirmed_need_line_decision_continuity
for select to atlas_need_generation_runtime
using (true);
create policy planning_contract_02b_materialization_decision_select
on atlas_planning.confirmed_need_line_decisions
for select to atlas_planning_materialization_runtime
using (source_kind = 'NEED_GENERATION');
create policy planning_contract_02b_generation_decision_select
on atlas_planning.confirmed_need_line_decisions
for select to atlas_need_generation_runtime
using (source_kind = 'NEED_GENERATION');
create policy planning_contract_02b_generation_line_select
on atlas_planning.confirmed_need_lines
for select to atlas_need_generation_runtime
using (source_kind = 'NEED_GENERATION');
create policy planning_contract_02b_generation_line_lock
on atlas_planning.confirmed_need_lines
for update to atlas_need_generation_runtime
using (source_kind = 'NEED_GENERATION') with check (false);
create policy planning_contract_02b_generation_revision_select
on atlas_planning.confirmed_need_line_revisions
for select to atlas_need_generation_runtime
using (source_kind = 'NEED_GENERATION');
create policy planning_contract_02b_generation_batch_select
on atlas_planning.confirmed_need_batches
for select to atlas_need_generation_runtime
using (source_kind = 'NEED_GENERATION');
create policy planning_contract_02b_materialization_line_invalidation
on atlas_planning.confirmed_need_lines
for update to atlas_planning_materialization_runtime
using (source_kind = 'NEED_GENERATION')
with check (source_kind = 'NEED_GENERATION');
create policy planning_contract_02b_generation_policy_root_select
on atlas_planning.planning_quantity_policies
for select to atlas_need_generation_runtime
using (true);
create policy planning_contract_02b_generation_policy_root_lock
on atlas_planning.planning_quantity_policies
for update to atlas_need_generation_runtime
using (true) with check (false);
create policy planning_contract_02b_generation_policy_revision_select
on atlas_planning.planning_quantity_policy_revisions
for select to atlas_need_generation_runtime
using (true);
create policy planning_contract_02b_materialization_policy_revision_select
on atlas_planning.planning_quantity_policy_revisions
for select to atlas_planning_materialization_runtime
using (true);

revoke all on table
  atlas_planning.confirmed_need_line_decision_continuity
from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_procurement_command_runtime, atlas_read_runtime;
grant select, insert on table
  atlas_planning.confirmed_need_line_decision_continuity
to atlas_planning_materialization_runtime;
grant select on table
  atlas_planning.confirmed_need_line_decision_continuity
to atlas_confirmed_need_review_runtime,
  atlas_need_generation_runtime;
grant select on table atlas_planning.confirmed_need_line_decisions
to atlas_planning_materialization_runtime,
  atlas_need_generation_runtime;
grant select on table
  atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_batches
to atlas_need_generation_runtime;
grant update (confirmed_need_line_id)
on atlas_planning.confirmed_need_lines
to atlas_need_generation_runtime;
grant update (current_confirmed_need_line_decision_id)
on atlas_planning.confirmed_need_lines
to atlas_planning_materialization_runtime;
grant update (confirmed_quantity)
on atlas_planning.confirmed_need_line_revisions
to atlas_planning_materialization_runtime;
grant select on table
  atlas_planning.planning_quantity_policies,
  atlas_planning.planning_quantity_policy_revisions
to atlas_need_generation_runtime;
grant select on table
  atlas_planning.planning_quantity_policy_revisions
to atlas_planning_materialization_runtime;
grant update (planning_quantity_policy_id)
on atlas_planning.planning_quantity_policies
to atlas_need_generation_runtime;

revoke all on function
  atlas_core.planning_contract_02b_decision_authorizes_revision(uuid, uuid, uuid),
  atlas_core.planning_contract_02b_invalidation_authorizes_clear(uuid, uuid),
  atlas_core.planning_contract_02b_removed_business_fact_count(
    uuid, uuid, bigint, uuid, uuid, bigint, uuid
  ),
  atlas_core.planning_contract_02b_extend_workbench(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.planning_contract_02b_decision_authorizes_revision(uuid, uuid, uuid),
  atlas_core.planning_contract_02b_invalidation_authorizes_clear(uuid, uuid)
to atlas_planning_materialization_runtime,
  atlas_confirmed_need_review_runtime,
  atlas_need_generation_runtime;
grant execute on function
  atlas_core.planning_contract_02b_removed_business_fact_count(
    uuid, uuid, bigint, uuid, uuid, bigint, uuid
  )
to atlas_planning_materialization_runtime,
  atlas_confirmed_need_review_runtime;
grant execute on function
  atlas_core.planning_contract_02b_extend_workbench(jsonb)
to atlas_confirmed_need_review_runtime;
reset role;
set role atlas_planning_materialization_runtime;
revoke all on function
  atlas_core.planning_contract_02b_apply_decision_continuity(
    uuid, uuid, bigint, uuid, uuid, bigint, uuid, uuid, uuid
  ),
  atlas_core.planning_contract_02b_policy_incompatible_batch(uuid, date, date)
from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_procurement_command_runtime, atlas_read_runtime;
grant execute on function
  atlas_core.planning_contract_02b_policy_incompatible_batch(uuid, date, date)
to atlas_confirmed_need_review_runtime,
  atlas_need_generation_runtime,
  atlas_planning_command_runtime;
reset role;
set role atlas_owner;

comment on table
  atlas_planning.confirmed_need_line_decision_continuity is
  'Immutable system evidence carrying or invalidating one current human Confirmed Need decision across one direct generated successor context.';
comment on column
  atlas_planning.confirmed_need_line_decision_continuity.initiated_by_actor_id is
  'Human actor who initiated generation; not authorship of the source human decision.';

reset role;

-- Patch the pinned H1B1 integrity implementation in place. Every replacement
-- is guarded by the exact merged function hash and a one-occurrence check.
do $$
declare
  v_oid oid;
  v_definition text;
  v_original text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_planning'
    and p.proname = 'pa_06e_h1b1_confirmed_need_line_decision_integrity'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) = '';
  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> '2d6df0ee2e5dde60ef89c4301b6f6bc3'
  then
    raise exception 'Unexpected H1B1 decision-integrity baseline';
  end if;

  v_original := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$    if v_line.current_confirmed_need_line_decision_id is null then
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
    end if;$old$,
$new$    if v_line.current_confirmed_need_line_decision_id is null then
      if exists (
        select 1
        from atlas_planning.confirmed_need_line_decisions decision
        where decision.confirmed_need_line_id = v_line_id
      ) and not exists (
        select 1
        from atlas_planning.confirmed_need_line_decisions latest
        join atlas_planning.confirmed_need_line_decision_continuity continuity
          on continuity.confirmed_need_line_id = latest.confirmed_need_line_id
         and continuity.source_confirmed_need_line_decision_id =
           latest.confirmed_need_line_decision_id
         and continuity.continuity_kind in (
           'INVALIDATED_PROPOSAL_CHANGE',
           'INVALIDATED_POLICY_INCOMPATIBLE',
           'INVALIDATED_LINE_REMOVED'
         )
        where latest.confirmed_need_line_id = v_line_id
          and latest.decision_number = (
            select max(history.decision_number)
            from atlas_planning.confirmed_need_line_decisions history
            where history.confirmed_need_line_id = v_line_id
          )
      ) then
        raise exception using
          errcode = '23514',
          message = 'Historical decisions require exact current invalidation evidence';
      end if;

      continue;
    end if;$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$      or not exists (
        select 1
        from atlas_planning.confirmed_need_line_revisions as revision
        where revision.confirmed_need_line_revision_id
            = v_current_decision.confirmed_need_line_revision_id
          and revision.confirmed_need_line_id = v_line_id
          and revision.is_current
      )$old$,
$new$      or not exists (
        select 1
        from atlas_planning.confirmed_need_line_revisions revision
        where revision.confirmed_need_line_id = v_line_id
          and revision.is_current
          and atlas_core.planning_contract_02b_decision_authorizes_revision(
            v_current_decision.confirmed_need_line_decision_id,
            v_line_id,
            revision.confirmed_need_line_revision_id
          )
      )$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$                    and revision.predecessor_revision_id is distinct from
                      predecessor_decision.confirmed_need_line_revision_id
$old$,
$new$                    and revision.predecessor_revision_id is distinct from
                      predecessor_decision.confirmed_need_line_revision_id
                    and not atlas_core.planning_contract_02b_decision_authorizes_revision(
                      predecessor_decision.confirmed_need_line_decision_id,
                      decision.confirmed_need_line_id,
                      revision.predecessor_revision_id
                    )
$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$    for v_current_decision in
      select decision.*
      from atlas_planning.confirmed_need_line_decisions as decision
      where decision.confirmed_need_line_id = v_line_id
$old$,
$new$    for v_current_decision in
      select decision.*
      from atlas_planning.confirmed_need_line_decisions as decision
      where decision.confirmed_need_line_id = v_line_id
        and decision.confirmed_need_line_decision_id =
          v_line.current_confirmed_need_line_decision_id
$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$          or decision.theoretical_quantity_before
            is distinct from revision.theoretical_quantity
$old$,
$new$          or decision.theoretical_quantity_before
            is distinct from revision.theoretical_quantity
          or (
            decision.predecessor_decision_id is not null
            and decision.reason_note is null
            and not exists (
              select 1
              from atlas_planning.confirmed_need_line_decision_continuity continuity
              where continuity.confirmed_need_line_id = decision.confirmed_need_line_id
                and continuity.source_confirmed_need_line_decision_id =
                  decision.predecessor_decision_id
                and continuity.continuity_kind in (
                  'INVALIDATED_PROPOSAL_CHANGE',
                  'INVALIDATED_POLICY_INCOMPATIBLE',
                  'INVALIDATED_LINE_REMOVED'
                )
            )
          )
$new$);

  if v_definition = v_original then
    raise exception 'H1B1 decision-integrity patch made no change';
  end if;
  execute v_definition;
end;
$$;

-- The legacy invalidation subcommand normally proves its standalone result by
-- forcing every deferred constraint immediately. Inside the existing atomic
-- execute_need_generation receipt, policy-incompatible decisions can only be
-- evidenced by the successor materializer later in the same transaction. In
-- that exact nested command context, defer the flush to the outer command's
-- existing post-materialization integrity boundary.
reset role;
grant create on schema atlas_api to atlas_need_generation_runtime;
set role atlas_need_generation_runtime;
do $$
declare
  v_oid oid;
  v_definition text;
  v_original text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_api'
    and p.proname = 'invalidate_need_generation_run'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'request jsonb';
  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> '8e3a0f063fd23c0e2f5c2dce5ece03d0'
  then
    raise exception 'Unexpected RMVP-04 invalidation baseline';
  end if;
  v_original := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$  set constraints all immediate;
  set constraints all deferred;
  v_after := pg_catalog.jsonb_build_object($old$,
$new$  if exists (
    select 1
    from atlas_core.command_receipts receipt
    where receipt.command_id = atlas_core.pa_05b_safe_uuid(
        request ->> 'command_id'
      )
      and receipt.command_name = 'execute_need_generation'
      and receipt.outcome = 'IN_PROGRESS'
      and atlas_core.planning_contract_02b_policy_incompatible_batch(
        atlas_core.pa_05b_safe_uuid(
          request -> 'payload' ->> 'need_generation_run_id'
        ),
        null,
        null
      )
  ) then
    set constraints all deferred;
  else
    set constraints all immediate;
    set constraints all deferred;
  end if;
  v_after := pg_catalog.jsonb_build_object($new$);
  if v_definition = v_original then
    raise exception 'RMVP-04 invalidation integrity-boundary patch made no change';
  end if;
  execute v_definition;
end;
$$;

do $$
declare
  v_patch record;
  v_oid oid;
  v_definition text;
  v_original text;
begin
  for v_patch in
    select *
    from (values
      ('create_need_generation_run', '34fc60b3ac9d860d6b05ba27438fb9e6'),
      ('validate_need_generation_run', '0a1d4928e0e58d7935ec127f926d719e'),
      ('release_need_generation_run', 'cda9df068ae764a7417e834c141a3663')
    ) expected(function_name, source_hash)
  loop
    select p.oid, pg_catalog.pg_get_functiondef(p.oid)
    into strict v_oid, v_definition
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname = v_patch.function_name
      and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'request jsonb';
    if pg_catalog.md5(
        (select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid)
      ) <> v_patch.source_hash
    then
      raise exception 'Unexpected RMVP-04 % baseline', v_patch.function_name;
    end if;
    v_original := v_definition;
    v_definition := pg_catalog.replace(v_definition,
$old$  set constraints all immediate;
  set constraints all deferred;
$old$,
$new$  if exists (
    select 1
    from atlas_core.command_receipts receipt
    where receipt.command_id = atlas_core.pa_05b_safe_uuid(
        request ->> 'command_id'
      )
      and receipt.command_name = 'execute_need_generation'
      and receipt.outcome in ('IN_PROGRESS', 'COMPLETED')
      and atlas_core.planning_contract_02b_policy_incompatible_batch(
        atlas_core.pa_05b_safe_uuid(
          request -> 'payload' ->> 'need_generation_run_id'
        ),
        atlas_core.rmvp_04_safe_date(request -> 'payload' ->> 'period_start'),
        atlas_core.rmvp_04_safe_date(request -> 'payload' ->> 'period_end')
      )
  ) then
    set constraints all deferred;
  else
    set constraints all immediate;
    set constraints all deferred;
  end if;
$new$);
    if v_definition = v_original then
      raise exception 'RMVP-04 % integrity-boundary patch made no change',
        v_patch.function_name;
    end if;
    execute v_definition;
  end loop;
end;
$$;
reset role;
revoke create on schema atlas_api from atlas_need_generation_runtime;
set role atlas_owner;

-- RMVP-03B also flushes every pending invariant before completing its nested
-- readiness invalidation. Defer that flush only for the same exact policy-
-- incompatible outer generation command; the outer materialization command
-- retains the existing explicit post-write integrity boundary.
do $$
declare
  v_oid oid;
  v_definition text;
  v_original text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core'
    and p.proname = 'rmvp_03b_finish_success'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) =
      'request jsonb, actor_id uuid, receipt_id uuid, event_type text, input_set_id uuid, evaluation_id uuid, evaluation_version bigint, before_summary jsonb, after_summary jsonb, safe_message text, source_selection jsonb';
  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> '7b4e420cfaaaaae375379e6831441d3e'
  then
    raise exception 'Unexpected RMVP-03B finish-success baseline';
  end if;
  v_original := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$begin
  set constraints all immediate;
  set constraints all deferred;
$old$,
$new$begin
  if exists (
    select 1
    from atlas_core.command_receipts receipt
    where receipt.command_id = atlas_core.pa_05b_safe_uuid(
        request ->> 'command_id'
      )
      and receipt.command_name = 'execute_need_generation'
      and receipt.outcome in ('IN_PROGRESS', 'COMPLETED')
      and atlas_core.planning_contract_02b_policy_incompatible_batch(
        null,
        atlas_core.rmvp_03b_safe_date(request -> 'payload' ->> 'period_start'),
        atlas_core.rmvp_03b_safe_date(request -> 'payload' ->> 'period_end')
      )
  ) then
    set constraints all deferred;
  else
    set constraints all immediate;
    set constraints all deferred;
  end if;
$new$);
  if v_definition = v_original then
    raise exception 'RMVP-03B nested integrity-boundary patch made no change';
  end if;
  execute v_definition;
end;
$$;

-- Patch the single materializer: accept exact 02A Recipe replacement removals,
-- apply 02B continuity before advancing the batch source pointer, and expose
-- authoritative command counts.
reset role;
set role atlas_planning_materialization_runtime;
do $$
declare
  v_oid oid;
  v_definition text;
  v_original text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core'
    and p.proname = 'planning_contract_01_materialize_confirmed_needs'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'request jsonb';
  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> '2abdbab83054d647ae36189ae4cf4a90'
  then
    raise exception 'Unexpected PLANNING-CONTRACT-01 materializer baseline';
  end if;
  v_original := v_definition;

  v_definition := pg_catalog.replace(v_definition,
$old$      and theoretical.contribution_family = 'RECIPE_DERIVED'
      and (selection.need_generation_recipe_selection_id is null or recipe_use.need_generation_recipe_line_use_id is null)
$old$,
$new$      and theoretical.contribution_family = 'RECIPE_DERIVED'
      and not (
        theoretical.line_disposition = 'REMOVED'
        and theoretical.recipe_replacement_predecessor_selection_id is not null
        and theoretical.recipe_replacement_successor_selection_id is not null
      )
      and (selection.need_generation_recipe_selection_id is null or recipe_use.need_generation_recipe_line_use_id is null)
$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$                   or (
                     successor.contribution_family = 'PANTRY_DIRECT'
                     and successor.line_disposition = 'REMOVED'
                   )
$old$,
$new$                   or (
                     successor.contribution_family = 'PANTRY_DIRECT'
                     and successor.line_disposition = 'REMOVED'
                   )
                   or (
                     successor.contribution_family = 'RECIPE_DERIVED'
                     and successor.line_disposition = 'REMOVED'
                     and successor.recipe_replacement_predecessor_selection_id is not null
                     and successor.recipe_replacement_successor_selection_id is not null
                   )
$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = new_theoretical.predecessor_theoretical_need_line_id
      left join atlas_planning.confirmed_need_line_revisions old_revision
$old$,
$new$      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = new_theoretical.predecessor_theoretical_need_line_id
       and exists (
         select 1
         from atlas_planning.confirmed_need_line_revisions current_predecessor
         where current_predecessor.confirmed_need_line_revision_id =
             old_contribution.confirmed_need_line_revision_id
           and current_predecessor.is_current
       )
      left join atlas_planning.confirmed_need_line_revisions old_revision
$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
$old$,
$new$      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
       and exists (
         select 1
         from atlas_planning.confirmed_need_line_revisions current_predecessor
         where current_predecessor.confirmed_need_line_revision_id =
             old_contribution.confirmed_need_line_revision_id
           and current_predecessor.is_current
       )
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
    join atlas_planning.confirmed_need_lines target_line
$old$,
$new$    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
     and exists (
       select 1
       from atlas_planning.confirmed_need_line_revisions current_predecessor
       where current_predecessor.confirmed_need_line_revision_id =
           old_contribution.confirmed_need_line_revision_id
         and current_predecessor.is_current
     )
    join atlas_planning.confirmed_need_lines target_line
$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$    v_event_type := 'ConfirmedNeedsRematerialized';

    update atlas_planning.confirmed_need_batches target_batch
$old$,
$new$    v_event_type := 'ConfirmedNeedsRematerialized';

    perform atlas_core.planning_contract_02b_apply_decision_continuity(
      v_batch_id,
      v_batch.current_need_generation_run_id,
      v_batch.current_need_generation_run_version,
      v_batch.current_need_generation_release_snapshot_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      v_actor_id
    );

    update atlas_planning.confirmed_need_batches target_batch
$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$    'superseded_line_revision_count', v_superseded_revision_count
  );$old$,
$new$    'superseded_line_revision_count', v_superseded_revision_count,
    'carried_forward_count', (
      select count(*)::integer
      from atlas_planning.confirmed_need_line_decision_continuity continuity
      where continuity.command_id = atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
        and continuity.continuity_kind = 'CARRIED_FORWARD'
    ),
    'needs_review_count', (
      select count(*)::integer
      from atlas_planning.confirmed_need_lines line
      join atlas_planning.confirmed_need_line_revisions revision
        on revision.confirmed_need_line_id = line.confirmed_need_line_id
       and revision.is_current
      where line.confirmed_need_batch_id = v_batch_id
        and line.current_confirmed_need_line_decision_id is null
    ),
    'changed_count', (
      select count(*)::integer
      from atlas_planning.confirmed_need_line_decision_continuity continuity
      where continuity.command_id = atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
        and continuity.continuity_kind in (
          'INVALIDATED_PROPOSAL_CHANGE',
          'INVALIDATED_POLICY_INCOMPATIBLE'
        )
    ),
    'new_count', v_created_line_count,
    'removed_count',
      atlas_core.planning_contract_02b_removed_business_fact_count(
        v_batch_id,
        v_batch.current_need_generation_run_id,
        v_batch.current_need_generation_run_version,
        v_batch.current_need_generation_release_snapshot_id,
        v_run_id,
        v_run_version,
        v_release.need_generation_release_snapshot_id
      )
  );$new$);

  if v_definition = v_original then
    raise exception 'Materializer patch made no change';
  end if;
  execute v_definition;
end;
$$;
reset role;
set role atlas_confirmed_need_review_runtime;

-- RMVP-06 validates current business facts only, and accepts an older human
-- decision revision only through exact carry evidence.
do $$
declare
  v_oid oid;
  v_definition text;
  v_original text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core'
    and p.proname = 'rmvp_06_canonical_evaluation'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) =
      'batch_id uuid, prior_fingerprint text';
  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> '9a09294e6558d9f674c856c52c78837a'
  then
    raise exception 'Unexpected RMVP-06 evaluation baseline';
  end if;
  v_original := v_definition;

  v_definition := pg_catalog.replace(v_definition,
$old$  select count(*)::integer into v_line_count
  from atlas_planning.confirmed_need_lines line
  where line.confirmed_need_batch_id = batch_id;$old$,
$new$  select count(*)::integer into v_line_count
  from atlas_planning.confirmed_need_lines line
  where line.confirmed_need_batch_id = batch_id
    and exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions revision
      where revision.confirmed_need_line_id = line.confirmed_need_line_id
        and revision.is_current
    );$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = batch_id
  ) then$old$,
$new$    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = batch_id
      and exists (
        select 1
        from atlas_planning.confirmed_need_line_revisions revision
        where revision.confirmed_need_line_id = line.confirmed_need_line_id
          and revision.is_current
      )
  ) then$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$    where line.confirmed_need_batch_id = batch_id
    order by line.confirmed_need_line_id
  loop$old$,
$new$    where line.confirmed_need_batch_id = batch_id
      and exists (
        select 1
        from atlas_planning.confirmed_need_line_revisions revision
        where revision.confirmed_need_line_id = line.confirmed_need_line_id
          and revision.is_current
      )
    order by line.confirmed_need_line_id
  loop$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$    if v_revision_count = 1 and v_decision_count = 1
      and v_decision.confirmed_need_line_revision_id
        is distinct from v_revision.confirmed_need_line_revision_id
    then$old$,
$new$    if v_revision_count = 1 and v_decision_count = 1
      and not atlas_core.planning_contract_02b_decision_authorizes_revision(
        v_decision.confirmed_need_line_decision_id,
        v_line.confirmed_need_line_id,
        v_revision.confirmed_need_line_revision_id
      )
    then$new$);

  v_definition := pg_catalog.replace(v_definition,
$old$      ) or (
        v_decision.predecessor_decision_id is not null
        and v_decision.reason_note is null
      ) then$old$,
$new$      ) or (
        v_decision.predecessor_decision_id is not null
        and v_decision.reason_note is null
        and not exists (
          select 1
          from atlas_planning.confirmed_need_line_decision_continuity continuity
          where continuity.confirmed_need_line_id = v_line.confirmed_need_line_id
            and continuity.source_confirmed_need_line_decision_id =
              v_decision.predecessor_decision_id
            and continuity.continuity_kind in (
              'INVALIDATED_PROPOSAL_CHANGE',
              'INVALIDATED_POLICY_INCOMPATIBLE',
              'INVALIDATED_LINE_REMOVED'
            )
        )
      ) then$new$);

  if v_definition = v_original then
    raise exception 'RMVP-06 evaluation patch made no change';
  end if;
  execute v_definition;
end;
$$;

reset role;
set role atlas_owner;

do $$
declare
  v_oid oid;
  v_definition text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_planning'
    and p.proname = 'rmvp_06_validation_integrity'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) = '';
  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> '84f24b840e6a7df34ad8668f08fa3815'
  then
    raise exception 'Unexpected RMVP-06 integrity baseline';
  end if;
  v_definition := pg_catalog.replace(v_definition,
$old$          or decision.confirmed_need_line_revision_id <> revision.confirmed_need_line_revision_id
$old$,
$new$          or not atlas_core.planning_contract_02b_decision_authorizes_revision(
            decision.confirmed_need_line_decision_id,
            observation.confirmed_need_line_id,
            revision.confirmed_need_line_revision_id
          )
$new$);
  execute v_definition;
end;
$$;

-- RMVP-07 completeness counts only current facts and uses the same exact
-- decision-authority predicate as RMVP-06.
reset role;
set role atlas_confirmed_need_review_runtime;

do $$
declare
  v_oid oid;
  v_definition text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core'
    and p.proname = 'rmvp_07_validation_evidence_complete'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) =
      'batch_id uuid, validation_attempt_id uuid, expected_resulting_version bigint';
  v_definition := pg_catalog.replace(v_definition,
$old$        from atlas_planning.confirmed_need_lines line
        where line.confirmed_need_batch_id = batch_id
$old$,
$new$        from atlas_planning.confirmed_need_lines line
        where line.confirmed_need_batch_id = batch_id
          and exists (
            select 1
            from atlas_planning.confirmed_need_line_revisions revision
            where revision.confirmed_need_line_id = line.confirmed_need_line_id
              and revision.is_current
          )
$new$);
  v_definition := pg_catalog.replace(v_definition,
$old$            or decision.confirmed_need_line_revision_id
              <> revision.confirmed_need_line_revision_id
$old$,
$new$            or not atlas_core.planning_contract_02b_decision_authorizes_revision(
              decision.confirmed_need_line_decision_id,
              observation.confirmed_need_line_id,
              revision.confirmed_need_line_revision_id
            )
$new$);
  execute v_definition;
end;
$$;

do $$
declare
  v_oid oid;
  v_definition text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core'
    and p.proname = 'rmvp_07_snapshot_current_complete'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) =
      'batch_id uuid, approval_snapshot_id uuid, expected_revision_status text';
  v_definition := pg_catalog.replace(v_definition,
$old$        = (select count(*)
           from atlas_planning.confirmed_need_lines line
           where line.confirmed_need_batch_id = batch_id)
$old$,
$new$        = (select count(*)
           from atlas_planning.confirmed_need_lines line
           join atlas_planning.confirmed_need_line_revisions revision
             on revision.confirmed_need_line_id = line.confirmed_need_line_id
            and revision.is_current
           where line.confirmed_need_batch_id = batch_id)
$new$);
  v_definition := pg_catalog.replace(v_definition,
$old$        from atlas_planning.confirmed_need_lines line
        left join atlas_planning.confirmed_need_line_revisions revision
          on revision.confirmed_need_line_id = line.confirmed_need_line_id
         and revision.is_current
$old$,
$new$        from atlas_planning.confirmed_need_lines line
        join atlas_planning.confirmed_need_line_revisions revision
          on revision.confirmed_need_line_id = line.confirmed_need_line_id
         and revision.is_current
$new$);
  execute v_definition;
end;
$$;

-- All v2 application readbacks pass through D037; extend that authoritative
-- payload without changing the public command surface.
do $$
declare
  v_oid oid;
  v_definition text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core'
    and p.proname = 'd037_extend_workbench'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) =
      'p_workbench jsonb, p_actor_id uuid';
  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> 'd7131e80c0afae9be0007c31c119ed1b'
  then
    raise exception 'Unexpected D037 workbench baseline';
  end if;
  v_definition := pg_catalog.replace(v_definition,
$old$begin
  select batch.* into strict v_batch
$old$,
$new$begin
  p_workbench := atlas_core.planning_contract_02b_extend_workbench(p_workbench);

  select batch.* into strict v_batch
$new$);
  execute v_definition;
end;
$$;

-- Owner/grant cleanup after CREATE OR REPLACE patches.
reset role;
set role atlas_owner;
revoke all on function
  atlas_planning.planning_contract_02b_continuity_immutable(),
  atlas_planning.planning_contract_02b_continuity_integrity(),
  atlas_planning.planning_contract_02b_continue_human_chain()
from public, anon, authenticated, service_role;
revoke create on schema atlas_core, atlas_planning
from atlas_planning_materialization_runtime,
  atlas_confirmed_need_review_runtime;
reset role;
revoke atlas_planning_materialization_runtime,
  atlas_confirmed_need_review_runtime,
  atlas_need_generation_runtime
from postgres;
