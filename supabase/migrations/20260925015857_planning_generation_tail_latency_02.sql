-- Bound the deferred current-source guard at the event that owns each fact.
-- Batch INSERT/source-advance UPDATE events retain the complete authoritative
-- proof. Immutable stable-line INSERTs and current-revision INSERTs validate
-- only their local source facts and affected release partition. UPDATE and
-- historical-revision paths retain the broader pre-existing validation.
-- No trigger, constraint, membership-total proof, API, timeout or privilege is
-- changed.
create or replace function atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid;
  v_line_id uuid;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
begin
  v_batch_id := new.confirmed_need_batch_id;

  select batch.* into strict v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;

  -- INSERT_EVENT_SCOPE: a stable-line event introduces only one immutable
  -- source identity. The batch event remains queued and proves completeness,
  -- including when constraints are flushed before any revision is inserted.
  if tg_op = 'INSERT' and tg_table_name = 'confirmed_need_lines' then
    if v_batch.source_kind = 'WHOLESALE' then
      if new.source_kind <> 'WHOLESALE' or not exists (
        select 1
        from atlas_planning.wholesale_order_lines source_line
        where source_line.wholesale_order_line_id = new.wholesale_order_line_id
          and source_line.wholesale_order_id = v_batch.wholesale_order_id
      ) then
        raise exception using errcode = '23514',
          message = 'Wholesale Confirmed Need source chain is inconsistent';
      end if;
    elsif new.source_kind <> 'NEED_GENERATION' then
      raise exception using errcode = '23514',
        message = 'Need Generation stable lines must agree with the batch source kind';
    end if;
    return null;
  end if;

  -- INSERT_EVENT_SCOPE: a new current revision owns one immutable identity,
  -- one predecessor edge and the release members attached to its stable line.
  -- The separate membership-total guard still proves nonempty exact facts,
  -- totals, predecessor provenance and completeness for this revision.
  if tg_op = 'INSERT'
     and tg_table_name = 'confirmed_need_line_revisions' then
    if not new.is_current then
      -- Historical revision INSERTs retain the broader path below.
      null;
    elsif v_batch.source_kind = 'WHOLESALE' then
      if not exists (
        select 1
        from atlas_planning.confirmed_need_lines line
        join atlas_planning.wholesale_order_line_revisions source_revision
          on source_revision.wholesale_order_line_revision_id = new.wholesale_order_line_revision_id
        where line.confirmed_need_line_id = new.confirmed_need_line_id
          and line.confirmed_need_batch_id = v_batch_id
          and line.source_kind = 'WHOLESALE'
          and new.source_kind = 'WHOLESALE'
          and source_revision.wholesale_order_line_id = line.wholesale_order_line_id
          and source_revision.ingredient_id = new.ingredient_id
          and source_revision.unit_id = new.unit_id
          and source_revision.requested_quantity = new.theoretical_quantity
          and new.confirmed_quantity = new.theoretical_quantity
      ) then
        raise exception using errcode = '23514',
          message = 'Wholesale Confirmed Need source chain is inconsistent';
      end if;
      return null;
    else

      if not exists (
      select 1
      from atlas_planning.confirmed_need_lines line
      join atlas_planning.need_generation_runs source_run
        on source_run.need_generation_run_id = new.need_generation_run_id
      join atlas_planning.need_generation_release_snapshots source_snapshot
        on source_snapshot.need_generation_release_snapshot_id = new.need_generation_release_snapshot_id
       and source_snapshot.need_generation_run_id = new.need_generation_run_id
       and source_snapshot.released_run_version = new.need_generation_run_version
      where line.confirmed_need_line_id = new.confirmed_need_line_id
        and line.confirmed_need_batch_id = v_batch_id
        and new.source_kind = 'NEED_GENERATION'
        and row(
          new.need_generation_run_id,
          new.need_generation_run_version,
          new.need_generation_release_snapshot_id
        ) = row(
          v_batch.current_need_generation_run_id,
          v_batch.current_need_generation_run_version,
          v_batch.current_need_generation_release_snapshot_id
        )
        and source_run.run_status = 'RELEASED_FOR_CONFIRMATION'
        and source_run.version = new.need_generation_run_version
        and source_run.period_start = v_batch.period_start
        and source_run.period_end = v_batch.period_end
        and row(
          new.service_date,
          new.customer_id,
          new.school_id,
          new.delivery_location_id,
          new.ingredient_id,
          new.unit_id
        ) = row(
          line.service_date,
          line.customer_id,
          line.school_id,
          line.delivery_location_id,
          line.ingredient_id,
          line.controlled_unit_id
        )
      ) then
        raise exception using errcode = '23514',
          message = 'Need Generation revision source or operational identity is inconsistent';
      end if;

      if (new.revision_number = 1 and new.predecessor_revision_id is not null)
         or (new.revision_number > 1 and not exists (
           select 1
           from atlas_planning.confirmed_need_line_revisions predecessor
           where predecessor.confirmed_need_line_revision_id = new.predecessor_revision_id
             and predecessor.confirmed_need_line_id = new.confirmed_need_line_id
             and predecessor.revision_number = new.revision_number - 1
         )) then
        raise exception using errcode = '23514',
          message = 'Need Generation current revision predecessor is stale';
      end if;

      if exists (
      select snapshot_line.need_generation_release_snapshot_line_id
      from atlas_planning.need_generation_release_snapshot_lines snapshot_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
      left join atlas_planning.confirmed_need_line_revision_contributions contribution
        on contribution.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
       and contribution.confirmed_need_batch_id = v_batch_id
       and contribution.need_generation_run_id = v_batch.current_need_generation_run_id
       and contribution.need_generation_run_version = v_batch.current_need_generation_run_version
       and contribution.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
      left join atlas_planning.confirmed_need_line_revisions revision
        on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
       and revision.confirmed_need_batch_id = v_batch_id
       and revision.source_kind = 'NEED_GENERATION'
       and revision.is_current
       and revision.need_generation_run_id = v_batch.current_need_generation_run_id
       and revision.need_generation_run_version = v_batch.current_need_generation_run_version
       and revision.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
      where snapshot_line.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
        and exists (
          select 1
          from atlas_planning.confirmed_need_line_revision_contributions affected
          where affected.confirmed_need_batch_id = v_batch_id
            and affected.confirmed_need_line_id = new.confirmed_need_line_id
            and affected.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
        )
      group by snapshot_line.need_generation_release_snapshot_line_id
      having count(revision.confirmed_need_line_revision_id) <> 1
      ) then
        raise exception using errcode = '23514',
          message = 'Current Need Generation revisions must exactly partition the active release';
      end if;
      return null;
    end if;
  end if;

  -- Existing UPDATE and historical-revision semantics begin here.
  if v_batch.source_kind = 'WHOLESALE' then
    if exists (
      select 1
      from atlas_planning.confirmed_need_lines line
      left join atlas_planning.wholesale_order_lines source_line
        on source_line.wholesale_order_line_id = line.wholesale_order_line_id
      where line.confirmed_need_batch_id = v_batch_id
        and (
          line.source_kind <> 'WHOLESALE'
          or source_line.wholesale_order_id is distinct from v_batch.wholesale_order_id
        )
    ) or exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions revision
      join atlas_planning.confirmed_need_lines line
        on line.confirmed_need_line_id = revision.confirmed_need_line_id
      left join atlas_planning.wholesale_order_line_revisions source_revision
        on source_revision.wholesale_order_line_revision_id = revision.wholesale_order_line_revision_id
      where revision.confirmed_need_batch_id = v_batch_id
        and (
          revision.source_kind <> 'WHOLESALE'
          or source_revision.wholesale_order_line_id is distinct from line.wholesale_order_line_id
          or source_revision.ingredient_id is distinct from revision.ingredient_id
          or source_revision.unit_id is distinct from revision.unit_id
          or source_revision.requested_quantity is distinct from revision.theoretical_quantity
          or revision.confirmed_quantity is distinct from revision.theoretical_quantity
        )
    ) or exists (
      select 1
      from atlas_planning.confirmed_need_line_revision_contributions contribution
      where contribution.confirmed_need_batch_id = v_batch_id
    ) then
      raise exception using errcode = '23514',
        message = 'Wholesale Confirmed Need source chain is inconsistent';
    end if;
    return null;
  end if;

  if tg_table_name in ('confirmed_need_lines', 'confirmed_need_line_revisions') then
    v_line_id := new.confirmed_need_line_id;
  end if;

  if not exists (
    select 1
    from atlas_planning.need_generation_runs origin_run
    join atlas_planning.need_generation_runs current_run
      on current_run.need_generation_run_id = v_batch.current_need_generation_run_id
    where origin_run.need_generation_run_id = v_batch.origin_need_generation_run_id
      and current_run.run_status = 'RELEASED_FOR_CONFIRMATION'
      and current_run.version = v_batch.current_need_generation_run_version
      and origin_run.planning_input_set_id = current_run.planning_input_set_id
      and origin_run.period_start = v_batch.period_start
      and origin_run.period_end = v_batch.period_end
      and current_run.period_start = v_batch.period_start
      and current_run.period_end = v_batch.period_end
  ) then
    raise exception using errcode = '23514',
      message = 'Need Generation batch source must be released with the exact input set and period';
  end if;

  if tg_table_name = 'confirmed_need_batches' then
    if tg_op = 'UPDATE'
       and row(
         new.current_need_generation_run_id,
         new.current_need_generation_run_version,
         new.current_need_generation_release_snapshot_id
       ) is distinct from row(
         old.current_need_generation_run_id,
         old.current_need_generation_run_version,
         old.current_need_generation_release_snapshot_id
       )
       and not exists (
         select 1
         from atlas_planning.need_generation_runs successor
         join atlas_planning.need_generation_runs predecessor
           on predecessor.need_generation_run_id = old.current_need_generation_run_id
         where successor.need_generation_run_id = new.current_need_generation_run_id
           and successor.predecessor_need_generation_run_id = old.current_need_generation_run_id
           and successor.planning_input_set_id = predecessor.planning_input_set_id
           and successor.period_start = predecessor.period_start
           and successor.period_end = predecessor.period_end
           and successor.run_status = 'RELEASED_FOR_CONFIRMATION'
       ) then
      raise exception using errcode = '23514',
        message = 'Need Generation current source may advance only to the direct released successor';
    end if;
  end if;

  if not exists (
    with recursive source_chain as (
      select run.need_generation_run_id, run.predecessor_need_generation_run_id
      from atlas_planning.need_generation_runs run
      where run.need_generation_run_id = v_batch.current_need_generation_run_id
      union all
      select predecessor.need_generation_run_id, predecessor.predecessor_need_generation_run_id
      from atlas_planning.need_generation_runs predecessor
      join source_chain child
        on child.predecessor_need_generation_run_id = predecessor.need_generation_run_id
    )
    select 1 from source_chain
    where need_generation_run_id = v_batch.origin_need_generation_run_id
  ) then
    raise exception using errcode = '23514',
      message = 'Need Generation current source is outside the origin predecessor chain';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = v_batch_id
      and (v_line_id is null or line.confirmed_need_line_id = v_line_id)
      and line.source_kind <> 'NEED_GENERATION'
  ) then
    raise exception using errcode = '23514',
      message = 'Need Generation stable lines must agree with the batch source kind';
  end if;

  if exists (
    with recursive source_chain as (
      select run.need_generation_run_id
      from atlas_planning.need_generation_runs run
      where run.need_generation_run_id = v_batch.current_need_generation_run_id
      union all
      select predecessor.need_generation_run_id
      from atlas_planning.need_generation_runs predecessor
      join atlas_planning.need_generation_runs child
        on child.predecessor_need_generation_run_id = predecessor.need_generation_run_id
      join source_chain chain
        on chain.need_generation_run_id = child.need_generation_run_id
    )
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_line_id = revision.confirmed_need_line_id
    where revision.confirmed_need_batch_id = v_batch_id
      and (v_line_id is null or revision.confirmed_need_line_id = v_line_id)
      and (
        revision.source_kind <> 'NEED_GENERATION'
        or revision.service_date is distinct from line.service_date
        or revision.customer_id is distinct from line.customer_id
        or revision.school_id is distinct from line.school_id
        or revision.delivery_location_id is distinct from line.delivery_location_id
        or revision.ingredient_id is distinct from line.ingredient_id
        or revision.unit_id is distinct from line.controlled_unit_id
        or not exists (
          select 1 from source_chain
          where source_chain.need_generation_run_id = revision.need_generation_run_id
        )
        or (
          revision.is_current and row(
            revision.need_generation_run_id,
            revision.need_generation_run_version,
            revision.need_generation_release_snapshot_id
          ) is distinct from row(
            v_batch.current_need_generation_run_id,
            v_batch.current_need_generation_run_version,
            v_batch.current_need_generation_release_snapshot_id
          )
        )
      )
  ) then
    raise exception using errcode = '23514',
      message = 'Need Generation revision source or operational identity is inconsistent';
  end if;

  if exists (
    select snapshot_line.need_generation_release_snapshot_line_id
    from atlas_planning.need_generation_release_snapshot_lines snapshot_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
    left join atlas_planning.confirmed_need_line_revision_contributions contribution
      on contribution.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
     and contribution.confirmed_need_batch_id = v_batch_id
     and contribution.need_generation_run_id = v_batch.current_need_generation_run_id
     and contribution.need_generation_run_version = v_batch.current_need_generation_run_version
     and contribution.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
    left join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
     and revision.confirmed_need_batch_id = v_batch_id
     and revision.source_kind = 'NEED_GENERATION'
     and revision.is_current
     and revision.need_generation_run_id = v_batch.current_need_generation_run_id
     and revision.need_generation_run_version = v_batch.current_need_generation_run_version
     and revision.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
    where snapshot_line.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and (v_line_id is null or exists (
        select 1
        from atlas_planning.confirmed_need_line_revision_contributions affected
        where affected.confirmed_need_batch_id = v_batch_id
          and affected.confirmed_need_line_id = v_line_id
          and affected.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
      ))
    group by snapshot_line.need_generation_release_snapshot_line_id
    having count(revision.confirmed_need_line_revision_id) <> 1
  ) then
    raise exception using errcode = '23514',
      message = 'Current Need Generation revisions must exactly partition the active release';
  end if;

  return null;
end;
$$;
