-- Weekly Menu Save: bound repeated deferred snapshot validation.
-- Preserve existing ownership, SECURITY INVOKER, empty search_path, trigger
-- registrations/deferral, immutable evidence and full header integrity checks.
-- No data, privilege, API, retry or timeout-setting changes.

create or replace function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_integrity_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_menu atlas_planning.weekly_menus%rowtype;
  target_snapshot atlas_planning.weekly_menu_approval_snapshots%rowtype;
  target_snapshot_id uuid;
begin
  if tg_table_name = 'weekly_menus' then
    if new.weekly_menu_status not in ('APPROVED', 'NEED_GENERATION_REQUESTED') then
      return null;
    end if;

    target_menu := new;
    target_snapshot_id := new.latest_approval_snapshot_id;
  elsif tg_table_name = 'weekly_menu_approval_snapshots' then
    select menu.*
      into target_menu
    from atlas_planning.weekly_menus menu
    where menu.weekly_menu_id = new.weekly_menu_id;
    target_snapshot_id := new.weekly_menu_approval_snapshot_id;
  else
    select menu.*
      into target_menu
    from atlas_planning.weekly_menus menu
    where menu.weekly_menu_id = new.weekly_menu_id;
    target_snapshot_id := new.weekly_menu_approval_snapshot_id;
  end if;

  if target_menu.weekly_menu_status not in ('APPROVED', 'NEED_GENERATION_REQUESTED')
    or target_menu.latest_approval_snapshot_id is distinct from target_snapshot_id
  then
    raise exception using
      errcode = '23514',
      message = 'an approval snapshot must be bound to the approved weekly menu at commit';
  end if;

  select snapshot.*
    into target_snapshot
  from atlas_planning.weekly_menu_approval_snapshots snapshot
  where snapshot.weekly_menu_approval_snapshot_id = target_snapshot_id;

  if not found
    or target_snapshot.weekly_menu_id is distinct from target_menu.weekly_menu_id
    or target_snapshot.weekly_menu_version is distinct from target_menu.version
    or target_snapshot.approved_by_actor_id is distinct from target_menu.latest_approved_by_actor_id
    or target_snapshot.approved_at is distinct from target_menu.latest_approved_at
  then
    raise exception using
      errcode = '23514',
      message = 'approved weekly menu evidence must match the exact current approval snapshot';
  end if;

  -- Snapshot-header and Weekly Menu approval events retain whole-set checks.
  -- Repeating those two anti-joins for EACH immutable child caused ordinary
  -- weekly Saves to exceed the authenticated statement timeout. A child event
  -- still proves its own exact membership and the parent binding above.
  -- No cache/GUC or user-controlled "already checked" flag skips validation.
  if tg_table_name = 'weekly_menu_approval_snapshot_lines' then
    if new.weekly_menu_version is distinct from target_snapshot.weekly_menu_version
      or not exists (
        select 1
        from atlas_planning.weekly_menu_lines line
        where line.weekly_menu_line_id = new.weekly_menu_line_id
          and line.weekly_menu_id = target_menu.weekly_menu_id
          and line.line_status = 'ACTIVE'
          and line.school_id = new.school_id
          and line.service_date = new.service_date
          and line.menu_slot_code = new.menu_slot_code
          and line.dish_id = new.dish_id
          and line.source_row_reference is not distinct from new.source_row_reference
      )
    then
      raise exception using
        errcode = '23514',
        message = 'approval snapshot may contain only exact active weekly menu lines';
    end if;
    return null;
  end if;

  if exists (
    select 1
    from atlas_planning.weekly_menu_lines line
    where line.weekly_menu_id = target_menu.weekly_menu_id
      and line.line_status = 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.weekly_menu_approval_snapshot_lines snapshot_line
        where snapshot_line.weekly_menu_approval_snapshot_id = target_snapshot_id
          and snapshot_line.weekly_menu_line_id = line.weekly_menu_line_id
          and snapshot_line.weekly_menu_id = line.weekly_menu_id
          and snapshot_line.weekly_menu_version = target_snapshot.weekly_menu_version
          and snapshot_line.school_id = line.school_id
          and snapshot_line.service_date = line.service_date
          and snapshot_line.menu_slot_code = line.menu_slot_code
          and snapshot_line.dish_id = line.dish_id
          and snapshot_line.source_row_reference is not distinct from line.source_row_reference
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot must contain every active weekly menu line exactly once';
  end if;

  if exists (
    select 1
    from atlas_planning.weekly_menu_approval_snapshot_lines snapshot_line
    left join atlas_planning.weekly_menu_lines line
      on line.weekly_menu_line_id = snapshot_line.weekly_menu_line_id
     and line.weekly_menu_id = snapshot_line.weekly_menu_id
    where snapshot_line.weekly_menu_approval_snapshot_id = target_snapshot_id
      and (
        line.weekly_menu_line_id is null
        or line.line_status <> 'ACTIVE'
        or snapshot_line.school_id is distinct from line.school_id
        or snapshot_line.service_date is distinct from line.service_date
        or snapshot_line.menu_slot_code is distinct from line.menu_slot_code
        or snapshot_line.dish_id is distinct from line.dish_id
        or snapshot_line.source_row_reference is distinct from line.source_row_reference
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot may contain only exact active weekly menu lines';
  end if;

  return null;
end
$$;
