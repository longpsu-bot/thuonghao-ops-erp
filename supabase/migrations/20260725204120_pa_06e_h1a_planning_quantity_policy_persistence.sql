-- PA-06E-H1A Planning quantity-policy persistence.
-- Private, seedless persistence only: no API, command, role, capability,
-- policy, positive grant, resolver, view, runtime, or hosted-system change.

set role atlas_owner;

create table atlas_planning.planning_quantity_policies (
  planning_quantity_policy_id uuid not null default gen_random_uuid(),
  unit_id uuid not null,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint planning_quantity_policies_pkey primary key (
    planning_quantity_policy_id
  ),
  constraint planning_quantity_policies_unit_key unique (unit_id),
  constraint planning_quantity_policies_id_unit_key unique (
    planning_quantity_policy_id,
    unit_id
  ),
  constraint planning_quantity_policies_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint planning_quantity_policies_created_by_actor_fkey foreign key (
    created_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict
);

create table atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id uuid not null default gen_random_uuid(),
  planning_quantity_policy_id uuid not null,
  unit_id uuid not null,
  revision_number bigint not null,
  predecessor_policy_revision_id uuid,
  planning_step numeric(20, 6) not null,
  effective_from date not null,
  effective_to date,
  policy_revision_status text not null default 'DRAFT',
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  approved_by_actor_id uuid,
  approved_at timestamptz,
  activated_by_actor_id uuid,
  activated_at timestamptz,
  retired_by_actor_id uuid,
  retired_at timestamptz,
  constraint planning_quantity_policy_revisions_pkey primary key (
    planning_quantity_policy_revision_id
  ),
  constraint planning_quantity_policy_revisions_policy_revision_key unique (
    planning_quantity_policy_id,
    revision_number
  ),
  constraint planning_quantity_policy_revisions_exact_owner_key unique (
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id
  ),
  constraint planning_quantity_policy_revisions_predecessor_key unique (
    planning_quantity_policy_id,
    predecessor_policy_revision_id
  ),
  constraint planning_quantity_policy_revisions_revision_number_check check (
    revision_number > 0
  ),
  constraint planning_quantity_policy_revisions_predecessor_shape_check check (
    (
      revision_number = 1
      and predecessor_policy_revision_id is null
    )
    or (
      revision_number > 1
      and predecessor_policy_revision_id is not null
    )
  ),
  constraint planning_quantity_policy_revisions_planning_step_check check (
    planning_step > 0
  ),
  constraint planning_quantity_policy_revisions_status_check check (
    policy_revision_status in ('DRAFT', 'ACTIVE', 'RETIRED')
  ),
  constraint planning_quantity_policy_revisions_period_check check (
    effective_to is null
    or effective_to > effective_from
  ),
  constraint planning_quantity_policy_revisions_evidence_check check (
    (approved_by_actor_id is null) = (approved_at is null)
    and (activated_by_actor_id is null) = (activated_at is null)
    and (retired_by_actor_id is null) = (retired_at is null)
    and (
      approved_at is null
      or approved_at >= created_at
    )
    and (
      activated_at is null
      or (
        approved_at is not null
        and activated_at >= approved_at
      )
    )
    and (
      retired_at is null
      or (
        activated_at is not null
        and retired_at >= activated_at
      )
    )
    and (
      (
        policy_revision_status = 'DRAFT'
        and activated_by_actor_id is null
        and activated_at is null
        and retired_by_actor_id is null
        and retired_at is null
      )
      or (
        policy_revision_status = 'ACTIVE'
        and approved_by_actor_id is not null
        and approved_at is not null
        and activated_by_actor_id is not null
        and activated_at is not null
        and retired_by_actor_id is null
        and retired_at is null
        and effective_to is null
      )
      or (
        policy_revision_status = 'RETIRED'
        and approved_by_actor_id is not null
        and approved_at is not null
        and activated_by_actor_id is not null
        and activated_at is not null
        and retired_by_actor_id is not null
        and retired_at is not null
        and effective_to is not null
      )
    )
  ),
  constraint planning_quantity_policy_revisions_policy_unit_fkey foreign key (
    planning_quantity_policy_id,
    unit_id
  ) references atlas_planning.planning_quantity_policies (
    planning_quantity_policy_id,
    unit_id
  ) on delete restrict,
  constraint planning_quantity_policy_revisions_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint planning_quantity_policy_revisions_predecessor_fkey foreign key (
    planning_quantity_policy_id,
    predecessor_policy_revision_id,
    unit_id
  ) references atlas_planning.planning_quantity_policy_revisions (
    planning_quantity_policy_id,
    planning_quantity_policy_revision_id,
    unit_id
  ) on delete restrict,
  constraint planning_quantity_policy_revisions_created_by_actor_fkey foreign key (
    created_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint planning_quantity_policy_revisions_approved_by_actor_fkey foreign key (
    approved_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint planning_quantity_policy_revisions_activated_by_actor_fkey foreign key (
    activated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint planning_quantity_policy_revisions_retired_by_actor_fkey foreign key (
    retired_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict
);

create index planning_quantity_policies_created_by_actor_idx
  on atlas_planning.planning_quantity_policies (created_by_actor_id);

create index planning_quantity_policy_revisions_policy_unit_idx
  on atlas_planning.planning_quantity_policy_revisions (
    planning_quantity_policy_id,
    unit_id
  );

create index planning_quantity_policy_revisions_unit_idx
  on atlas_planning.planning_quantity_policy_revisions (unit_id);

create index planning_quantity_policy_revisions_resolution_idx
  on atlas_planning.planning_quantity_policy_revisions (
    unit_id,
    policy_revision_status,
    effective_from,
    effective_to,
    planning_quantity_policy_revision_id
  )
  where policy_revision_status in ('ACTIVE', 'RETIRED');

create index planning_quantity_policy_revisions_predecessor_idx
  on atlas_planning.planning_quantity_policy_revisions (
    predecessor_policy_revision_id,
    planning_quantity_policy_id,
    unit_id
  )
  where predecessor_policy_revision_id is not null;

create index planning_quantity_policy_revisions_created_by_actor_idx
  on atlas_planning.planning_quantity_policy_revisions (created_by_actor_id);

create index planning_quantity_policy_revisions_approved_by_actor_idx
  on atlas_planning.planning_quantity_policy_revisions (approved_by_actor_id)
  where approved_by_actor_id is not null;

create index planning_quantity_policy_revisions_activated_by_actor_idx
  on atlas_planning.planning_quantity_policy_revisions (activated_by_actor_id)
  where activated_by_actor_id is not null;

create index planning_quantity_policy_revisions_retired_by_actor_idx
  on atlas_planning.planning_quantity_policy_revisions (retired_by_actor_id)
  where retired_by_actor_id is not null;

create function atlas_planning.pa_06e_h1a_planning_quantity_policy_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'planning quantity policies cannot be deleted';
  end if;

  if new.planning_quantity_policy_id is distinct from old.planning_quantity_policy_id
    or new.unit_id is distinct from old.unit_id
    or new.created_by_actor_id is distinct from old.created_by_actor_id
    or new.created_at is distinct from old.created_at
  then
    raise exception using
      errcode = '23514',
      message = 'planning quantity policy identity, Unit, creator, and creation time are immutable';
  end if;

  return new;
end;
$$;

create function atlas_planning.pa_06e_h1a_planning_quantity_policy_revision_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_planning_quantity_policy_id uuid;
  v_unit_id uuid;
  v_locked_policy_id uuid;
begin
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'planning quantity policy revisions cannot be deleted';
  end if;

  if tg_op = 'INSERT' then
    v_planning_quantity_policy_id := new.planning_quantity_policy_id;
    v_unit_id := new.unit_id;
  elsif tg_op = 'UPDATE' then
    v_planning_quantity_policy_id := old.planning_quantity_policy_id;
    v_unit_id := old.unit_id;
  end if;

  select policy.planning_quantity_policy_id
  into v_locked_policy_id
  from atlas_planning.planning_quantity_policies as policy
  where policy.planning_quantity_policy_id = v_planning_quantity_policy_id
    and policy.unit_id = v_unit_id
  for update;

  if v_locked_policy_id is null then
    raise exception using
      errcode = '23503',
      message = 'planning quantity policy revision requires its exact parent policy and Unit';
  end if;

  if tg_op = 'INSERT' then
    if new.policy_revision_status <> 'DRAFT' then
      raise exception using
        errcode = '23514',
        message = 'planning quantity policy revisions must be inserted as DRAFT';
    end if;
    return new;
  end if;

  if new.planning_quantity_policy_revision_id
      is distinct from old.planning_quantity_policy_revision_id
    or new.planning_quantity_policy_id
      is distinct from old.planning_quantity_policy_id
    or new.unit_id is distinct from old.unit_id
    or new.revision_number is distinct from old.revision_number
    or new.predecessor_policy_revision_id
      is distinct from old.predecessor_policy_revision_id
    or new.created_by_actor_id is distinct from old.created_by_actor_id
    or new.created_at is distinct from old.created_at
  then
    raise exception using
      errcode = '23514',
      message = 'planning quantity policy revision identity, ownership, lineage, creator, and creation time are immutable';
  end if;

  if old.policy_revision_status = 'DRAFT' then
    if new.policy_revision_status = 'DRAFT' then
      return new;
    end if;

    if new.policy_revision_status = 'ACTIVE' then
      return new;
    end if;

    raise exception using
      errcode = '23514',
      message = 'planning quantity policy revisions follow DRAFT to ACTIVE to RETIRED';
  end if;

  if old.policy_revision_status = 'ACTIVE' then
    if new.policy_revision_status <> 'RETIRED' then
      raise exception using
        errcode = '23514',
        message = 'ACTIVE planning quantity policy revisions may only be retired';
    end if;

    if new.planning_step is distinct from old.planning_step
      or new.effective_from is distinct from old.effective_from
      or new.approved_by_actor_id is distinct from old.approved_by_actor_id
      or new.approved_at is distinct from old.approved_at
      or new.activated_by_actor_id is distinct from old.activated_by_actor_id
      or new.activated_at is distinct from old.activated_at
    then
      raise exception using
        errcode = '23514',
        message = 'ACTIVE planning quantity policy payload and approval or activation evidence are immutable';
    end if;

    if old.effective_to is not null
      or new.effective_to is null
      or new.retired_by_actor_id is null
      or new.retired_at is null
    then
      raise exception using
        errcode = '23514',
        message = 'retirement must atomically close the open interval and record paired evidence';
    end if;

    return new;
  end if;

  raise exception using
    errcode = '23514',
    message = 'RETIRED planning quantity policy revisions are immutable';
end;
$$;

create function atlas_planning.pa_06e_h1a_planning_quantity_policy_effectivity_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_revision atlas_planning.planning_quantity_policy_revisions%rowtype;
  v_revision_count bigint;
  v_min_revision_number bigint;
  v_max_revision_number bigint;
begin
  select revision.*
  into v_revision
  from atlas_planning.planning_quantity_policy_revisions as revision
  where revision.planning_quantity_policy_revision_id
    = new.planning_quantity_policy_revision_id;

  if v_revision.planning_quantity_policy_revision_id is null then
    return new;
  end if;

  if not exists (
    select 1
    from atlas_planning.planning_quantity_policies as policy
    where policy.planning_quantity_policy_id
      = v_revision.planning_quantity_policy_id
      and policy.unit_id = v_revision.unit_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'planning quantity policy revision must agree with its exact root and Unit';
  end if;

  select
    count(*),
    min(revision.revision_number),
    max(revision.revision_number)
  into
    v_revision_count,
    v_min_revision_number,
    v_max_revision_number
  from atlas_planning.planning_quantity_policy_revisions as revision
  where revision.planning_quantity_policy_id
    = v_revision.planning_quantity_policy_id;

  if v_min_revision_number <> 1
    or v_max_revision_number <> v_revision_count
  then
    raise exception using
      errcode = '23514',
      message = 'planning quantity policy revision numbers must be positive and contiguous within the root';
  end if;

  if exists (
    select 1
    from atlas_planning.planning_quantity_policy_revisions as revision
    where revision.planning_quantity_policy_id
      = v_revision.planning_quantity_policy_id
      and (
        (
          revision.revision_number = 1
          and revision.predecessor_policy_revision_id is not null
        )
        or (
          revision.revision_number > 1
          and not exists (
            select 1
            from atlas_planning.planning_quantity_policy_revisions as predecessor
            where predecessor.planning_quantity_policy_id
              = revision.planning_quantity_policy_id
              and predecessor.planning_quantity_policy_revision_id
                = revision.predecessor_policy_revision_id
              and predecessor.unit_id = revision.unit_id
              and predecessor.revision_number = revision.revision_number - 1
          )
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'each planning quantity policy revision must name its direct same-root and same-Unit predecessor';
  end if;

  if exists (
    select 1
    from atlas_planning.planning_quantity_policy_revisions as successor
    where successor.planning_quantity_policy_id
      = v_revision.planning_quantity_policy_id
      and successor.predecessor_policy_revision_id is not null
    group by
      successor.planning_quantity_policy_id,
      successor.predecessor_policy_revision_id
    having count(*) > 1
  ) then
    raise exception using
      errcode = '23514',
      message = 'planning quantity policy revision predecessors cannot fork';
  end if;

  if exists (
    select 1
    from atlas_planning.planning_quantity_policy_revisions as revision
    where revision.planning_quantity_policy_id
      = v_revision.planning_quantity_policy_id
      and (
        revision.revision_number <= 0
        or revision.planning_step <= 0
        or (
          revision.effective_to is not null
          and revision.effective_to <= revision.effective_from
        )
        or (revision.approved_by_actor_id is null) <> (revision.approved_at is null)
        or (revision.activated_by_actor_id is null) <> (revision.activated_at is null)
        or (revision.retired_by_actor_id is null) <> (revision.retired_at is null)
        or (
          revision.policy_revision_status = 'DRAFT'
          and (
            revision.activated_by_actor_id is not null
            or revision.retired_by_actor_id is not null
          )
        )
        or (
          revision.policy_revision_status = 'ACTIVE'
          and (
            revision.approved_by_actor_id is null
            or revision.activated_by_actor_id is null
            or revision.retired_by_actor_id is not null
            or revision.effective_to is not null
          )
        )
        or (
          revision.policy_revision_status = 'RETIRED'
          and (
            revision.approved_by_actor_id is null
            or revision.activated_by_actor_id is null
            or revision.retired_by_actor_id is null
            or revision.effective_to is null
          )
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'planning quantity policy revision evidence and half-open period shape are invalid';
  end if;

  if exists (
    select 1
    from atlas_planning.planning_quantity_policy_revisions as candidate
    join atlas_planning.planning_quantity_policy_revisions as existing
      on existing.unit_id = candidate.unit_id
      and existing.planning_quantity_policy_revision_id
        <> candidate.planning_quantity_policy_revision_id
    where candidate.unit_id = v_revision.unit_id
      and candidate.policy_revision_status in ('ACTIVE', 'RETIRED')
      and existing.policy_revision_status in ('ACTIVE', 'RETIRED')
      and existing.effective_from
        < coalesce(candidate.effective_to, 'infinity'::date)
      and candidate.effective_from
        < coalesce(existing.effective_to, 'infinity'::date)
  ) then
    raise exception using
      errcode = '23514',
      message = 'ACTIVE and RETIRED planning quantity policy intervals cannot overlap for one exact Unit';
  end if;

  return new;
end;
$$;

create trigger planning_quantity_policies_guard
before update or delete on atlas_planning.planning_quantity_policies
for each row
execute function atlas_planning.pa_06e_h1a_planning_quantity_policy_guard();

create trigger planning_quantity_policy_revisions_guard
before insert or update or delete
on atlas_planning.planning_quantity_policy_revisions
for each row
execute function atlas_planning.pa_06e_h1a_planning_quantity_policy_revision_guard();

create constraint trigger planning_quantity_policy_revisions_effectivity_integrity
after insert or update on atlas_planning.planning_quantity_policy_revisions
deferrable initially deferred
for each row
execute function atlas_planning.pa_06e_h1a_planning_quantity_policy_effectivity_integrity();

alter table atlas_planning.planning_quantity_policies enable row level security;
alter table atlas_planning.planning_quantity_policies force row level security;
alter table atlas_planning.planning_quantity_policy_revisions enable row level security;
alter table atlas_planning.planning_quantity_policy_revisions force row level security;

revoke all on table atlas_planning.planning_quantity_policies
  from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_planning_materialization_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;
revoke all on table atlas_planning.planning_quantity_policy_revisions
  from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_planning_materialization_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;

revoke all on function
  atlas_planning.pa_06e_h1a_planning_quantity_policy_guard()
  from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_planning_materialization_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;
revoke all on function
  atlas_planning.pa_06e_h1a_planning_quantity_policy_revision_guard()
  from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_planning_materialization_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;
revoke all on function
  atlas_planning.pa_06e_h1a_planning_quantity_policy_effectivity_integrity()
  from public, anon, authenticated, service_role,
  atlas_command_runtime, atlas_dispatch_command_runtime,
  atlas_evidence_command_runtime, atlas_planning_command_runtime,
  atlas_planning_materialization_runtime, atlas_procurement_command_runtime,
  atlas_read_runtime;

reset role;
