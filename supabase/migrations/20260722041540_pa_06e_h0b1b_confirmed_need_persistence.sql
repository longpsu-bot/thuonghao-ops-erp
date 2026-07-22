-- PA-06E-H0B1b: typed Confirmed Need sources and immutable contribution membership.
-- This migration is additive and preserves the PA-05D API, grants, policies, and rows.

set role atlas_owner;

alter table atlas_admin.schools
  add constraint schools_customer_id_school_id_key unique (customer_id, school_id);

alter table atlas_planning.need_generation_release_snapshot_lines
  add constraint need_generation_release_snapshot_lines_exact_owner_key unique (
    need_generation_release_snapshot_line_id,
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version,
    theoretical_need_line_id
  );

alter table atlas_planning.theoretical_need_lines
  add constraint theoretical_need_lines_confirmed_need_owner_key unique (
    theoretical_need_line_id,
    need_generation_run_id,
    service_date,
    school_id,
    ingredient_id,
    unit_id,
    line_disposition,
    theoretical_quantity
  ),
  add constraint theoretical_need_lines_confirmed_need_fkey_key unique (
    theoretical_need_line_id,
    need_generation_run_id,
    service_date,
    school_id,
    ingredient_id,
    unit_id,
    theoretical_quantity
  );

alter table atlas_planning.confirmed_need_batches
  add column source_kind text not null default 'WHOLESALE',
  add column origin_need_generation_run_id uuid,
  add column origin_need_generation_run_version bigint,
  add column origin_need_generation_release_snapshot_id uuid,
  add column current_need_generation_run_id uuid,
  add column current_need_generation_run_version bigint,
  add column current_need_generation_release_snapshot_id uuid,
  add constraint confirmed_need_batches_source_kind_check check (
    source_kind in ('WHOLESALE', 'NEED_GENERATION')
  ),
  add constraint confirmed_need_batches_source_family_check check (
    (
      source_kind = 'WHOLESALE'
      and wholesale_order_id is not null
      and origin_need_generation_run_id is null
      and origin_need_generation_run_version is null
      and origin_need_generation_release_snapshot_id is null
      and current_need_generation_run_id is null
      and current_need_generation_run_version is null
      and current_need_generation_release_snapshot_id is null
    ) or (
      source_kind = 'NEED_GENERATION'
      and wholesale_order_id is null
      and origin_need_generation_run_id is not null
      and origin_need_generation_run_version is not null
      and origin_need_generation_run_version > 0
      and origin_need_generation_release_snapshot_id is not null
      and current_need_generation_run_id is not null
      and current_need_generation_run_version is not null
      and current_need_generation_run_version > 0
      and current_need_generation_release_snapshot_id is not null
    )
  ),
  add constraint confirmed_need_batches_id_source_key unique (
    confirmed_need_batch_id,
    source_kind
  ),
  add constraint confirmed_need_batches_origin_release_fkey foreign key (
    origin_need_generation_release_snapshot_id,
    origin_need_generation_run_id,
    origin_need_generation_run_version
  ) references atlas_planning.need_generation_release_snapshots (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  ) on delete restrict,
  add constraint confirmed_need_batches_current_release_fkey foreign key (
    current_need_generation_release_snapshot_id,
    current_need_generation_run_id,
    current_need_generation_run_version
  ) references atlas_planning.need_generation_release_snapshots (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  ) on delete restrict,
  alter column wholesale_order_id drop not null;

create unique index confirmed_need_batches_origin_release_key
  on atlas_planning.confirmed_need_batches (
    origin_need_generation_release_snapshot_id
  )
  where source_kind = 'NEED_GENERATION';

create index confirmed_need_batches_current_release_idx
  on atlas_planning.confirmed_need_batches (
    current_need_generation_release_snapshot_id,
    current_need_generation_run_id,
    current_need_generation_run_version
  )
  where source_kind = 'NEED_GENERATION';

alter table atlas_planning.confirmed_need_lines
  add column source_kind text not null default 'WHOLESALE',
  add column service_date date,
  add column customer_id uuid,
  add column school_id uuid,
  add column delivery_location_id uuid,
  add column ingredient_id uuid,
  add column controlled_unit_id uuid,
  add constraint confirmed_need_lines_source_kind_check check (
    source_kind in ('WHOLESALE', 'NEED_GENERATION')
  ),
  add constraint confirmed_need_lines_source_family_check check (
    (
      source_kind = 'WHOLESALE'
      and wholesale_order_line_id is not null
      and service_date is null
      and customer_id is null
      and school_id is null
      and delivery_location_id is null
      and ingredient_id is null
      and controlled_unit_id is null
    ) or (
      source_kind = 'NEED_GENERATION'
      and wholesale_order_line_id is null
      and service_date is not null
      and customer_id is not null
      and school_id is not null
      and delivery_location_id is not null
      and ingredient_id is not null
      and controlled_unit_id is not null
    )
  ),
  add constraint confirmed_need_lines_batch_source_fkey foreign key (
    confirmed_need_batch_id,
    source_kind
  ) references atlas_planning.confirmed_need_batches (
    confirmed_need_batch_id,
    source_kind
  ) on delete restrict,
  add constraint confirmed_need_lines_school_customer_fkey foreign key (
    customer_id,
    school_id
  ) references atlas_admin.schools (
    customer_id,
    school_id
  ) on delete restrict,
  add constraint confirmed_need_lines_location_customer_fkey foreign key (
    customer_id,
    delivery_location_id
  ) references atlas_admin.delivery_locations (
    customer_id,
    delivery_location_id
  ) on delete restrict,
  add constraint confirmed_need_lines_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  add constraint confirmed_need_lines_controlled_unit_fkey foreign key (controlled_unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  add constraint confirmed_need_lines_exact_owner_key unique (
    confirmed_need_line_id,
    confirmed_need_batch_id,
    source_kind,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    controlled_unit_id
  ),
  alter column wholesale_order_line_id drop not null;

create unique index confirmed_need_lines_operational_identity_key
  on atlas_planning.confirmed_need_lines (
    confirmed_need_batch_id,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    controlled_unit_id
  )
  where source_kind = 'NEED_GENERATION';

create index confirmed_need_lines_school_location_idx
  on atlas_planning.confirmed_need_lines (
    customer_id,
    school_id,
    delivery_location_id
  )
  where source_kind = 'NEED_GENERATION';

alter table atlas_planning.confirmed_need_line_revisions
  add column source_kind text not null default 'WHOLESALE',
  add column confirmed_need_batch_id uuid,
  add column need_generation_run_id uuid,
  add column need_generation_run_version bigint,
  add column need_generation_release_snapshot_id uuid,
  add column service_date date,
  add column customer_id uuid,
  add column school_id uuid,
  add column delivery_location_id uuid;

update atlas_planning.confirmed_need_line_revisions revision
set confirmed_need_batch_id = line.confirmed_need_batch_id
from atlas_planning.confirmed_need_lines line
where line.confirmed_need_line_id = revision.confirmed_need_line_id;

alter table atlas_planning.confirmed_need_line_revisions
  alter column confirmed_need_batch_id set not null,
  alter column wholesale_order_line_revision_id drop not null,
  add constraint confirmed_need_line_revisions_source_kind_check check (
    source_kind in ('WHOLESALE', 'NEED_GENERATION')
  ),
  add constraint confirmed_need_line_revisions_source_family_check check (
    (
      source_kind = 'WHOLESALE'
      and wholesale_order_line_revision_id is not null
      and need_generation_run_id is null
      and need_generation_run_version is null
      and need_generation_release_snapshot_id is null
      and service_date is null
      and customer_id is null
      and school_id is null
      and delivery_location_id is null
    ) or (
      source_kind = 'NEED_GENERATION'
      and wholesale_order_line_revision_id is null
      and need_generation_run_id is not null
      and need_generation_run_version is not null
      and need_generation_run_version > 0
      and need_generation_release_snapshot_id is not null
      and service_date is not null
      and customer_id is not null
      and school_id is not null
      and delivery_location_id is not null
    )
  ),
  add constraint confirmed_need_line_revisions_line_owner_fkey foreign key (
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
  add constraint confirmed_need_line_revisions_release_fkey foreign key (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    need_generation_run_version
  ) references atlas_planning.need_generation_release_snapshots (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  ) on delete restrict,
  add constraint confirmed_need_line_revisions_exact_owner_key unique (
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
  ),
  add constraint confirmed_need_line_revisions_contribution_owner_key unique (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    need_generation_run_id,
    need_generation_run_version,
    need_generation_release_snapshot_id,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id
  );

create index confirmed_need_line_revisions_release_idx
  on atlas_planning.confirmed_need_line_revisions (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    need_generation_run_version
  )
  where source_kind = 'NEED_GENERATION';

create table atlas_planning.confirmed_need_line_revision_contributions (
  confirmed_need_line_revision_contribution_id uuid not null default gen_random_uuid(),
  confirmed_need_batch_id uuid not null,
  confirmed_need_line_id uuid not null,
  confirmed_need_line_revision_id uuid not null,
  need_generation_run_id uuid not null,
  need_generation_run_version bigint not null,
  need_generation_release_snapshot_id uuid not null,
  need_generation_release_snapshot_line_id uuid not null,
  theoretical_need_line_id uuid not null,
  service_date date not null,
  customer_id uuid not null,
  school_id uuid not null,
  delivery_location_id uuid not null,
  ingredient_id uuid not null,
  source_unit_id uuid not null,
  controlled_unit_id uuid not null,
  source_theoretical_quantity numeric(20, 6) not null,
  controlled_contribution_quantity numeric(20, 6) not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint confirmed_need_line_revision_contributions_pkey primary key (
    confirmed_need_line_revision_contribution_id
  ),
  constraint confirmed_need_line_revision_contributions_member_key unique (
    confirmed_need_line_revision_id,
    theoretical_need_line_id
  ),
  constraint confirmed_need_line_revision_contributions_quantity_check check (
    source_theoretical_quantity >= 0
    and controlled_contribution_quantity = source_theoretical_quantity
  ),
  constraint confirmed_need_line_revision_contributions_unit_check check (
    controlled_unit_id = source_unit_id
  ),
  constraint confirmed_need_line_revision_contributions_revision_fkey foreign key (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
    need_generation_run_id,
    need_generation_run_version,
    need_generation_release_snapshot_id,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    controlled_unit_id
  ) references atlas_planning.confirmed_need_line_revisions (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id,
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
  constraint confirmed_need_line_revision_contributions_snapshot_line_fkey foreign key (
    need_generation_release_snapshot_line_id,
    need_generation_release_snapshot_id,
    need_generation_run_id,
    need_generation_run_version,
    theoretical_need_line_id
  ) references atlas_planning.need_generation_release_snapshot_lines (
    need_generation_release_snapshot_line_id,
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version,
    theoretical_need_line_id
  ) on delete restrict,
  constraint confirmed_need_line_revision_contributions_theoretical_line_fkey foreign key (
    theoretical_need_line_id,
    need_generation_run_id,
    service_date,
    school_id,
    ingredient_id,
    source_unit_id,
    source_theoretical_quantity
  ) references atlas_planning.theoretical_need_lines (
    theoretical_need_line_id,
    need_generation_run_id,
    service_date,
    school_id,
    ingredient_id,
    unit_id,
    theoretical_quantity
  ) on delete restrict,
  constraint confirmed_need_line_revision_contributions_school_fkey foreign key (
    customer_id,
    school_id
  ) references atlas_admin.schools (
    customer_id,
    school_id
  ) on delete restrict,
  constraint confirmed_need_line_revision_contributions_location_fkey foreign key (
    customer_id,
    delivery_location_id
  ) references atlas_admin.delivery_locations (
    customer_id,
    delivery_location_id
  ) on delete restrict
);

create index confirmed_need_line_revision_contributions_revision_idx
  on atlas_planning.confirmed_need_line_revision_contributions (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    confirmed_need_batch_id
  );
create index confirmed_need_line_revision_contributions_snapshot_idx
  on atlas_planning.confirmed_need_line_revision_contributions (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    need_generation_run_version
  );
create index confirmed_need_line_revision_contributions_source_line_idx
  on atlas_planning.confirmed_need_line_revision_contributions (
    theoretical_need_line_id,
    need_generation_run_id
  );

create function atlas_planning.pa_06e_h0b1b_confirmed_need_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_line atlas_planning.confirmed_need_lines%rowtype;
begin
  if tg_table_name = 'confirmed_need_batches' then
    if tg_op = 'INSERT'
       and new.source_kind = 'NEED_GENERATION'
       and row(
         new.current_need_generation_run_id,
         new.current_need_generation_run_version,
         new.current_need_generation_release_snapshot_id
       ) is distinct from row(
         new.origin_need_generation_run_id,
         new.origin_need_generation_run_version,
         new.origin_need_generation_release_snapshot_id
       ) then
      raise exception using errcode = '23514', message = 'Need Generation batch current source must initially equal origin';
    end if;

    if tg_op = 'UPDATE' and row(
      new.source_kind,
      new.wholesale_order_id,
      new.origin_need_generation_run_id,
      new.origin_need_generation_run_version,
      new.origin_need_generation_release_snapshot_id,
      new.period_start,
      new.period_end
    ) is distinct from row(
      old.source_kind,
      old.wholesale_order_id,
      old.origin_need_generation_run_id,
      old.origin_need_generation_run_version,
      old.origin_need_generation_release_snapshot_id,
      old.period_start,
      old.period_end
    ) then
      raise exception using errcode = '23514', message = 'Confirmed Need batch origin identity is immutable';
    end if;
    return new;
  end if;

  if tg_table_name = 'confirmed_need_lines' then
    if tg_op = 'UPDATE' and row(
      new.confirmed_need_batch_id,
      new.source_kind,
      new.wholesale_order_line_id,
      new.service_date,
      new.customer_id,
      new.school_id,
      new.delivery_location_id,
      new.ingredient_id,
      new.controlled_unit_id
    ) is distinct from row(
      old.confirmed_need_batch_id,
      old.source_kind,
      old.wholesale_order_line_id,
      old.service_date,
      old.customer_id,
      old.school_id,
      old.delivery_location_id,
      old.ingredient_id,
      old.controlled_unit_id
    ) then
      raise exception using errcode = '23514', message = 'Confirmed Need stable-line source identity is immutable';
    end if;
    return new;
  end if;

  if tg_table_name = 'confirmed_need_line_revisions' then
    select line.* into strict v_line
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_line_id = new.confirmed_need_line_id;

    if new.confirmed_need_batch_id is null then
      new.confirmed_need_batch_id := v_line.confirmed_need_batch_id;
    end if;

    if new.confirmed_need_batch_id <> v_line.confirmed_need_batch_id
       or new.source_kind <> v_line.source_kind then
      raise exception using errcode = '23514', message = 'Confirmed Need revision source must agree with its stable line';
    end if;

    if tg_op = 'UPDATE' and row(
      new.confirmed_need_line_id,
      new.confirmed_need_batch_id,
      new.source_kind,
      new.wholesale_order_line_revision_id,
      new.need_generation_run_id,
      new.need_generation_run_version,
      new.need_generation_release_snapshot_id,
      new.service_date,
      new.customer_id,
      new.school_id,
      new.delivery_location_id,
      new.ingredient_id,
      new.unit_id,
      new.theoretical_quantity
    ) is distinct from row(
      old.confirmed_need_line_id,
      old.confirmed_need_batch_id,
      old.source_kind,
      old.wholesale_order_line_revision_id,
      old.need_generation_run_id,
      old.need_generation_run_version,
      old.need_generation_release_snapshot_id,
      old.service_date,
      old.customer_id,
      old.school_id,
      old.delivery_location_id,
      old.ingredient_id,
      old.unit_id,
      old.theoretical_quantity
    ) then
      raise exception using errcode = '23514', message = 'Confirmed Need revision source identity and theoretical total are immutable';
    end if;
    return new;
  end if;

  if tg_table_name = 'confirmed_need_line_revision_contributions' then
    if tg_op <> 'INSERT' then
      raise exception using errcode = '23514', message = 'Confirmed Need contribution membership is immutable and nondeletable';
    end if;

    if not exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions revision
      join atlas_planning.confirmed_need_lines line
        on line.confirmed_need_line_id = revision.confirmed_need_line_id
      join atlas_planning.confirmed_need_batches batch
        on batch.confirmed_need_batch_id = revision.confirmed_need_batch_id
      join atlas_planning.need_generation_release_snapshot_lines snapshot_line
        on snapshot_line.need_generation_release_snapshot_line_id = new.need_generation_release_snapshot_line_id
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = new.theoretical_need_line_id
      where revision.confirmed_need_line_revision_id = new.confirmed_need_line_revision_id
        and revision.source_kind = 'NEED_GENERATION'
        and new.confirmed_need_batch_id = revision.confirmed_need_batch_id
        and new.confirmed_need_line_id = revision.confirmed_need_line_id
        and new.need_generation_run_id = revision.need_generation_run_id
        and new.need_generation_run_version = revision.need_generation_run_version
        and new.need_generation_release_snapshot_id = revision.need_generation_release_snapshot_id
        and batch.source_kind = 'NEED_GENERATION'
        and snapshot_line.need_generation_release_snapshot_id = revision.need_generation_release_snapshot_id
        and snapshot_line.need_generation_run_id = revision.need_generation_run_id
        and snapshot_line.released_run_version = revision.need_generation_run_version
        and snapshot_line.theoretical_need_line_id = theoretical.theoretical_need_line_id
        and theoretical.need_generation_run_id = revision.need_generation_run_id
        and theoretical.line_disposition = 'ACTIVE'
        and theoretical.service_date = line.service_date
        and theoretical.school_id = line.school_id
        and theoretical.ingredient_id = line.ingredient_id
        and theoretical.unit_id = line.controlled_unit_id
        and theoretical.theoretical_quantity = new.source_theoretical_quantity
        and new.controlled_contribution_quantity = new.source_theoretical_quantity
        and new.source_unit_id = theoretical.unit_id
        and new.controlled_unit_id = theoretical.unit_id
        and new.service_date = line.service_date
        and new.customer_id = line.customer_id
        and new.school_id = line.school_id
        and new.delivery_location_id = line.delivery_location_id
        and new.ingredient_id = line.ingredient_id
    ) then
      raise exception using errcode = '23514', message = 'Confirmed Need contribution does not match the exact active release member';
    end if;
    return new;
  end if;

  raise exception using errcode = '23514', message = 'Unexpected Confirmed Need guard target';
end;
$$;

create function atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
begin
  if tg_table_name = 'confirmed_need_batches' then
    v_batch_id := new.confirmed_need_batch_id;
  elsif tg_table_name = 'confirmed_need_lines' then
    v_batch_id := new.confirmed_need_batch_id;
  else
    v_batch_id := new.confirmed_need_batch_id;
  end if;

  select batch.* into strict v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;

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
      raise exception using errcode = '23514', message = 'Wholesale Confirmed Need source chain is inconsistent';
    end if;
    return null;
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
    raise exception using errcode = '23514', message = 'Need Generation batch source must be released with the exact input set and period';
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
      raise exception using errcode = '23514', message = 'Need Generation current source may advance only to the direct released successor';
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
    raise exception using errcode = '23514', message = 'Need Generation current source is outside the origin predecessor chain';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = v_batch_id
      and line.source_kind <> 'NEED_GENERATION'
  ) then
    raise exception using errcode = '23514', message = 'Need Generation stable lines must agree with the batch source kind';
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
    raise exception using errcode = '23514', message = 'Need Generation revision source or operational identity is inconsistent';
  end if;

  return null;
end;
$$;

create function atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()
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
            and theoretical.service_date = revision.service_date
            and theoretical.school_id = revision.school_id
            and theoretical.ingredient_id = revision.ingredient_id
            and theoretical.unit_id = revision.unit_id
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

create trigger confirmed_need_batches_h0b1b_guard
before insert or update on atlas_planning.confirmed_need_batches
for each row execute function atlas_planning.pa_06e_h0b1b_confirmed_need_guard();

create trigger confirmed_need_lines_h0b1b_guard
before insert or update on atlas_planning.confirmed_need_lines
for each row execute function atlas_planning.pa_06e_h0b1b_confirmed_need_guard();

create trigger confirmed_need_line_revisions_h0b1b_guard
before insert or update on atlas_planning.confirmed_need_line_revisions
for each row execute function atlas_planning.pa_06e_h0b1b_confirmed_need_guard();

create trigger confirmed_need_line_revision_contributions_h0b1b_guard
before insert or update or delete on atlas_planning.confirmed_need_line_revision_contributions
for each row execute function atlas_planning.pa_06e_h0b1b_confirmed_need_guard();

create constraint trigger confirmed_need_batches_current_source_consistency
after insert or update on atlas_planning.confirmed_need_batches
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency();

create constraint trigger confirmed_need_lines_current_source_consistency
after insert or update on atlas_planning.confirmed_need_lines
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency();

create constraint trigger confirmed_need_line_revisions_current_source_consistency
after insert or update on atlas_planning.confirmed_need_line_revisions
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency();

create constraint trigger confirmed_need_line_revisions_membership_total
after insert or update on atlas_planning.confirmed_need_line_revisions
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total();

create constraint trigger confirmed_need_line_revision_contributions_membership_total
after insert on atlas_planning.confirmed_need_line_revision_contributions
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total();

alter table atlas_planning.confirmed_need_line_revision_contributions enable row level security;
alter table atlas_planning.confirmed_need_line_revision_contributions force row level security;

alter function atlas_planning.pa_06e_h0b1b_confirmed_need_guard() owner to atlas_owner;
alter function atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency() owner to atlas_owner;
alter function atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total() owner to atlas_owner;

revoke all on table atlas_planning.confirmed_need_line_revision_contributions
  from public, anon, authenticated, service_role, atlas_planning_command_runtime;
revoke execute on function atlas_planning.pa_06e_h0b1b_confirmed_need_guard()
  from public, anon, authenticated, service_role, atlas_planning_command_runtime;
revoke execute on function atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()
  from public, anon, authenticated, service_role, atlas_planning_command_runtime;
revoke execute on function atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()
  from public, anon, authenticated, service_role, atlas_planning_command_runtime;

comment on table atlas_planning.confirmed_need_line_revision_contributions is
  'Immutable exact Need Generation release membership owned by one Confirmed Need line revision.';
comment on column atlas_planning.confirmed_need_batches.source_kind is
  'Typed WHOLESALE or NEED_GENERATION source family; defaults only for PA-05D compatibility.';
comment on column atlas_planning.confirmed_need_line_revisions.confirmed_quantity is
  'Draft proposal for NEED_GENERATION; not authoritative source evidence.';

reset role;
