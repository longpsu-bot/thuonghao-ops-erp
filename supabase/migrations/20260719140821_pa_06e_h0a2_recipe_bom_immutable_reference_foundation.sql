-- PA-06E-H0A2: private immutable Dish, Recipe, and BOM reference foundation.
--
-- This additive migration creates reference structure only. It adds no API,
-- command, capability, seed, calculation engine, legacy data, or hosted action.

set role atlas_owner;

create table atlas_admin.dishes (
  dish_id uuid not null default gen_random_uuid(),
  dish_code text not null,
  dish_name text not null,
  dish_category text,
  operational_notes text,
  dish_status text not null default 'DRAFT',
  display_order integer not null default 0,
  requires_need_generation boolean not null default true,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint dishes_pkey primary key (dish_id),
  constraint dishes_dish_code_key unique (dish_code),
  constraint dishes_dish_code_check check (
    dish_code = lower(dish_code)
    and btrim(dish_code) <> ''
  ),
  constraint dishes_dish_name_check check (btrim(dish_name) <> ''),
  constraint dishes_status_check check (
    dish_status in ('DRAFT', 'ACTIVE', 'INACTIVE')
  ),
  constraint dishes_display_order_check check (display_order >= 0),
  constraint dishes_version_check check (version > 0)
);

create unique index dishes_active_normalized_name_key
  on atlas_admin.dishes (lower(btrim(dish_name)))
  where dish_status = 'ACTIVE';
create index dishes_status_display_order_idx
  on atlas_admin.dishes (dish_status, display_order);

create table atlas_admin.recipes (
  recipe_id uuid not null default gen_random_uuid(),
  dish_id uuid not null,
  school_type_id uuid,
  recipe_status text not null default 'ACTIVE',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint recipes_pkey primary key (recipe_id),
  constraint recipes_dish_fkey foreign key (dish_id)
    references atlas_admin.dishes (dish_id) on delete restrict,
  constraint recipes_school_type_fkey foreign key (school_type_id)
    references atlas_admin.school_types (school_type_id) on delete restrict,
  constraint recipes_status_check check (recipe_status in ('ACTIVE', 'INACTIVE')),
  constraint recipes_version_check check (version > 0)
);

create unique index recipes_active_general_dish_key
  on atlas_admin.recipes (dish_id)
  where recipe_status = 'ACTIVE' and school_type_id is null;
create unique index recipes_active_typed_dish_school_type_key
  on atlas_admin.recipes (dish_id, school_type_id)
  where recipe_status = 'ACTIVE' and school_type_id is not null;
create index recipes_dish_idx on atlas_admin.recipes (dish_id);
create index recipes_school_type_idx
  on atlas_admin.recipes (school_type_id)
  where school_type_id is not null;

create table atlas_admin.recipe_versions (
  recipe_version_id uuid not null default gen_random_uuid(),
  recipe_id uuid not null,
  version_number integer not null,
  predecessor_recipe_version_id uuid,
  basis_portions integer not null,
  recipe_version_status text not null default 'DRAFT',
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  validated_by_actor_id uuid,
  validated_at timestamptz,
  released_by_actor_id uuid,
  released_at timestamptz,
  locked_by_actor_id uuid,
  locked_at timestamptz,
  constraint recipe_versions_pkey primary key (recipe_version_id),
  constraint recipe_versions_recipe_fkey foreign key (recipe_id)
    references atlas_admin.recipes (recipe_id) on delete restrict,
  constraint recipe_versions_id_recipe_key unique (recipe_version_id, recipe_id),
  constraint recipe_versions_predecessor_fkey foreign key (
    predecessor_recipe_version_id,
    recipe_id
  ) references atlas_admin.recipe_versions (recipe_version_id, recipe_id)
    on delete restrict,
  constraint recipe_versions_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint recipe_versions_validated_by_actor_fkey foreign key (validated_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint recipe_versions_released_by_actor_fkey foreign key (released_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint recipe_versions_locked_by_actor_fkey foreign key (locked_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint recipe_versions_recipe_number_key unique (recipe_id, version_number),
  constraint recipe_versions_number_check check (version_number > 0),
  constraint recipe_versions_predecessor_check check (
    predecessor_recipe_version_id is null
    or predecessor_recipe_version_id <> recipe_version_id
  ),
  constraint recipe_versions_basis_portions_check check (basis_portions > 0),
  constraint recipe_versions_status_check check (
    recipe_version_status in (
      'DRAFT',
      'VALIDATED',
      'RELEASED_FOR_PLANNING',
      'LOCKED'
    )
  ),
  constraint recipe_versions_lifecycle_evidence_check check (
    (
      recipe_version_status = 'DRAFT'
      and validated_by_actor_id is null
      and validated_at is null
      and released_by_actor_id is null
      and released_at is null
      and locked_by_actor_id is null
      and locked_at is null
    )
    or (
      recipe_version_status = 'VALIDATED'
      and validated_by_actor_id is not null
      and validated_at is not null
      and released_by_actor_id is null
      and released_at is null
      and locked_by_actor_id is null
      and locked_at is null
    )
    or (
      recipe_version_status = 'RELEASED_FOR_PLANNING'
      and validated_by_actor_id is not null
      and validated_at is not null
      and released_by_actor_id is not null
      and released_at is not null
      and locked_by_actor_id is null
      and locked_at is null
    )
    or (
      recipe_version_status = 'LOCKED'
      and validated_by_actor_id is not null
      and validated_at is not null
      and released_by_actor_id is not null
      and released_at is not null
      and locked_by_actor_id is not null
      and locked_at is not null
    )
  )
);

create unique index recipe_versions_current_release_key
  on atlas_admin.recipe_versions (recipe_id)
  where recipe_version_status = 'RELEASED_FOR_PLANNING';
create index recipe_versions_predecessor_recipe_idx
  on atlas_admin.recipe_versions (predecessor_recipe_version_id, recipe_id)
  where predecessor_recipe_version_id is not null;
create index recipe_versions_created_by_actor_idx
  on atlas_admin.recipe_versions (created_by_actor_id);
create index recipe_versions_validated_by_actor_idx
  on atlas_admin.recipe_versions (validated_by_actor_id)
  where validated_by_actor_id is not null;
create index recipe_versions_released_by_actor_idx
  on atlas_admin.recipe_versions (released_by_actor_id)
  where released_by_actor_id is not null;
create index recipe_versions_locked_by_actor_idx
  on atlas_admin.recipe_versions (locked_by_actor_id)
  where locked_by_actor_id is not null;

create table atlas_admin.recipe_lines (
  recipe_line_id uuid not null default gen_random_uuid(),
  recipe_id uuid not null,
  line_code text,
  created_at timestamptz not null default transaction_timestamp(),
  constraint recipe_lines_pkey primary key (recipe_line_id),
  constraint recipe_lines_recipe_fkey foreign key (recipe_id)
    references atlas_admin.recipes (recipe_id) on delete restrict,
  constraint recipe_lines_id_recipe_key unique (recipe_line_id, recipe_id),
  constraint recipe_lines_line_code_check check (
    line_code is null
    or (line_code = lower(line_code) and btrim(line_code) <> '')
  )
);

create unique index recipe_lines_recipe_line_code_key
  on atlas_admin.recipe_lines (recipe_id, line_code)
  where line_code is not null;
create index recipe_lines_recipe_idx on atlas_admin.recipe_lines (recipe_id);

create table atlas_admin.recipe_line_revisions (
  recipe_line_revision_id uuid not null default gen_random_uuid(),
  recipe_id uuid not null,
  recipe_version_id uuid not null,
  recipe_line_id uuid not null,
  line_revision_number integer not null,
  predecessor_recipe_line_revision_id uuid,
  ingredient_id uuid not null,
  quantity_per_basis numeric(20, 6) not null,
  unit_id uuid not null,
  line_disposition text not null default 'PRESENT',
  calculation_kind text not null default 'PROPORTIONAL_PER_BASIS',
  operational_note text,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint recipe_line_revisions_pkey primary key (recipe_line_revision_id),
  constraint recipe_line_revisions_id_ownership_key unique (
    recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  ),
  constraint recipe_line_revisions_version_fkey foreign key (
    recipe_version_id,
    recipe_id
  ) references atlas_admin.recipe_versions (recipe_version_id, recipe_id)
    on delete restrict,
  constraint recipe_line_revisions_line_fkey foreign key (
    recipe_line_id,
    recipe_id
  ) references atlas_admin.recipe_lines (recipe_line_id, recipe_id)
    on delete restrict,
  constraint recipe_line_revisions_predecessor_fkey foreign key (
    predecessor_recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  ) references atlas_admin.recipe_line_revisions (
    recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  ) on delete restrict,
  constraint recipe_line_revisions_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint recipe_line_revisions_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint recipe_line_revisions_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint recipe_line_revisions_version_line_key unique (
    recipe_version_id,
    recipe_line_id
  ),
  constraint recipe_line_revisions_line_number_key unique (
    recipe_line_id,
    line_revision_number
  ),
  constraint recipe_line_revisions_number_check check (line_revision_number > 0),
  constraint recipe_line_revisions_predecessor_check check (
    predecessor_recipe_line_revision_id is null
    or predecessor_recipe_line_revision_id <> recipe_line_revision_id
  ),
  constraint recipe_line_revisions_disposition_check check (
    line_disposition in ('PRESENT', 'REMOVED')
  ),
  constraint recipe_line_revisions_quantity_disposition_check check (
    (
      line_disposition = 'PRESENT'
      and quantity_per_basis > 0
    )
    or (
      line_disposition = 'REMOVED'
      and quantity_per_basis = 0
      and predecessor_recipe_line_revision_id is not null
    )
  ),
  constraint recipe_line_revisions_calculation_kind_check check (
    calculation_kind = 'PROPORTIONAL_PER_BASIS'
  )
);

create unique index recipe_line_revisions_predecessor_successor_key
  on atlas_admin.recipe_line_revisions (predecessor_recipe_line_revision_id)
  where predecessor_recipe_line_revision_id is not null;
create unique index recipe_line_revisions_present_ingredient_key
  on atlas_admin.recipe_line_revisions (recipe_version_id, ingredient_id)
  where line_disposition = 'PRESENT';
create index recipe_line_revisions_version_recipe_idx
  on atlas_admin.recipe_line_revisions (recipe_version_id, recipe_id);
create index recipe_line_revisions_line_recipe_idx
  on atlas_admin.recipe_line_revisions (recipe_line_id, recipe_id);
create index recipe_line_revisions_predecessor_ownership_idx
  on atlas_admin.recipe_line_revisions (
    predecessor_recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  )
  where predecessor_recipe_line_revision_id is not null;
create index recipe_line_revisions_ingredient_idx
  on atlas_admin.recipe_line_revisions (ingredient_id);
create index recipe_line_revisions_unit_idx
  on atlas_admin.recipe_line_revisions (unit_id);
create index recipe_line_revisions_created_by_actor_idx
  on atlas_admin.recipe_line_revisions (created_by_actor_id);

create function atlas_admin.pa_06e_h0a2_recipe_version_lifecycle_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  current_release atlas_admin.recipe_versions%rowtype;
begin
  if tg_table_name = 'recipes' then
    if new.dish_id is distinct from old.dish_id
      or new.school_type_id is distinct from old.school_type_id
    then
      raise exception using
        errcode = '23514',
        message = 'recipe dish and school type scope are immutable';
    end if;

    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.recipe_version_status <> 'DRAFT' then
      raise exception using
        errcode = '23514',
        message = 'new recipe versions must enter as DRAFT';
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.recipe_version_status in ('RELEASED_FOR_PLANNING', 'LOCKED') then
      raise exception using
        errcode = '23514',
        message = 'released or locked recipe versions cannot be deleted';
    end if;
    return old;
  end if;

  if new.recipe_version_id is distinct from old.recipe_version_id
    or new.recipe_id is distinct from old.recipe_id
    or new.version_number is distinct from old.version_number
    or new.predecessor_recipe_version_id is distinct from old.predecessor_recipe_version_id
    or new.created_by_actor_id is distinct from old.created_by_actor_id
    or new.created_at is distinct from old.created_at
  then
    raise exception using
      errcode = '23514',
      message = 'recipe version identity and predecessor are immutable';
  end if;

  if old.validated_by_actor_id is not null
    and (
      new.validated_by_actor_id is distinct from old.validated_by_actor_id
      or new.validated_at is distinct from old.validated_at
    )
  then
    raise exception using
      errcode = '23514',
      message = 'established recipe validation evidence is immutable';
  end if;

  if old.released_by_actor_id is not null
    and (
      new.released_by_actor_id is distinct from old.released_by_actor_id
      or new.released_at is distinct from old.released_at
    )
  then
    raise exception using
      errcode = '23514',
      message = 'established recipe release evidence is immutable';
  end if;

  if old.locked_by_actor_id is not null
    and (
      new.locked_by_actor_id is distinct from old.locked_by_actor_id
      or new.locked_at is distinct from old.locked_at
    )
  then
    raise exception using
      errcode = '23514',
      message = 'established recipe lock evidence is immutable';
  end if;

  if old.recipe_version_status = 'LOCKED' and new is distinct from old then
    raise exception using
      errcode = '23514',
      message = 'locked recipe versions are immutable';
  end if;

  if old.recipe_version_status <> 'DRAFT'
    and new.basis_portions is distinct from old.basis_portions
  then
    raise exception using
      errcode = '23514',
      message = 'validated, released, and locked recipe basis is immutable';
  end if;

  if new.recipe_version_status = old.recipe_version_status then
    if old.recipe_version_status <> 'DRAFT' and new is distinct from old then
      raise exception using
        errcode = '23514',
        message = 'non-draft recipe versions change only through the next lifecycle transition';
    end if;
    return new;
  end if;

  if not (
    (old.recipe_version_status = 'DRAFT' and new.recipe_version_status = 'VALIDATED')
    or (
      old.recipe_version_status = 'VALIDATED'
      and new.recipe_version_status = 'RELEASED_FOR_PLANNING'
    )
    or (
      old.recipe_version_status = 'RELEASED_FOR_PLANNING'
      and new.recipe_version_status = 'LOCKED'
    )
  ) then
    raise exception using
      errcode = '23514',
      message = 'recipe version lifecycle transition is invalid';
  end if;

  if new.recipe_version_status = 'RELEASED_FOR_PLANNING' then
    select existing_version.*
      into current_release
    from atlas_admin.recipe_versions existing_version
    where existing_version.recipe_id = new.recipe_id
      and existing_version.recipe_version_status = 'RELEASED_FOR_PLANNING'
      and existing_version.recipe_version_id <> new.recipe_version_id
    for update;

    if found then
      if new.predecessor_recipe_version_id is distinct from current_release.recipe_version_id then
        raise exception using
          errcode = '23514',
          message = 'a successor release must directly follow the current released version';
      end if;

      update atlas_admin.recipe_versions
      set recipe_version_status = 'LOCKED',
          locked_by_actor_id = new.released_by_actor_id,
          locked_at = new.released_at
      where recipe_version_id = current_release.recipe_version_id;
    end if;
  end if;

  return new;
end
$$;

create function atlas_admin.pa_06e_h0a2_recipe_line_revision_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_version atlas_admin.recipe_versions%rowtype;
  predecessor_revision atlas_admin.recipe_line_revisions%rowtype;
begin
  if tg_table_name = 'recipe_lines' then
    if new.recipe_id is distinct from old.recipe_id then
      raise exception using
        errcode = '23514',
        message = 'stable recipe line ownership is immutable';
    end if;

    return new;
  end if;

  if tg_op = 'UPDATE' or tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'recipe line revisions are immutable';
  end if;

  select recipe_version.*
    into target_version
  from atlas_admin.recipe_versions recipe_version
  where recipe_version.recipe_version_id = new.recipe_version_id;

  if not found then
    return new;
  end if;

  if target_version.recipe_version_status <> 'DRAFT' then
    raise exception using
      errcode = '23514',
      message = 'recipe composition can be inserted only for a draft version';
  end if;

  if new.predecessor_recipe_line_revision_id is null then
    if new.line_revision_number <> 1 then
      raise exception using
        errcode = '23514',
        message = 'a new recipe line starts at revision number one';
    end if;

    if exists (
      select 1
      from atlas_admin.recipe_line_revisions existing_revision
      where existing_revision.recipe_line_id = new.recipe_line_id
    ) then
      raise exception using
        errcode = '23514',
        message = 'an existing stable recipe line requires an exact predecessor revision';
    end if;

    return new;
  end if;

  select prior_revision.*
    into predecessor_revision
  from atlas_admin.recipe_line_revisions prior_revision
  where prior_revision.recipe_line_revision_id = new.predecessor_recipe_line_revision_id;

  if not found then
    return new;
  end if;

  if target_version.predecessor_recipe_version_id is null
    or predecessor_revision.recipe_version_id is distinct from target_version.predecessor_recipe_version_id
  then
    raise exception using
      errcode = '23514',
      message = 'line predecessor must belong to the exact predecessor recipe version';
  end if;

  if predecessor_revision.recipe_id is distinct from new.recipe_id
    or predecessor_revision.recipe_line_id is distinct from new.recipe_line_id
  then
    raise exception using
      errcode = '23514',
      message = 'line predecessor must retain exact recipe and stable line ownership';
  end if;

  if new.line_revision_number <> predecessor_revision.line_revision_number + 1 then
    raise exception using
      errcode = '23514',
      message = 'line successor revision number must follow its predecessor';
  end if;

  return new;
end
$$;

create function atlas_admin.pa_06e_h0a2_recipe_version_integrity_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  requires_generation boolean;
  predecessor_status text;
  predecessor_released_at timestamptz;
begin
  if new.recipe_version_status not in (
    'VALIDATED',
    'RELEASED_FOR_PLANNING',
    'LOCKED'
  ) then
    return null;
  end if;

  select dish.requires_need_generation
    into requires_generation
  from atlas_admin.recipes recipe
  join atlas_admin.dishes dish on dish.dish_id = recipe.dish_id
  where recipe.recipe_id = new.recipe_id;

  if requires_generation and not exists (
    select 1
    from atlas_admin.recipe_line_revisions line_revision
    where line_revision.recipe_version_id = new.recipe_version_id
      and line_revision.line_disposition = 'PRESENT'
  ) then
    raise exception using
      errcode = '23514',
      message = 'a need-generation recipe version requires a present composition';
  end if;

  if new.predecessor_recipe_version_id is null then
    if exists (
      select 1
      from atlas_admin.recipe_line_revisions line_revision
      where line_revision.recipe_version_id = new.recipe_version_id
        and line_revision.predecessor_recipe_line_revision_id is not null
    ) then
      raise exception using
        errcode = '23514',
        message = 'an initial recipe version cannot reference predecessor line revisions';
    end if;
  else
    if exists (
      select 1
      from atlas_admin.recipe_line_revisions prior_revision
      where prior_revision.recipe_version_id = new.predecessor_recipe_version_id
        and prior_revision.line_disposition = 'PRESENT'
        and not exists (
          select 1
          from atlas_admin.recipe_line_revisions successor_revision
          where successor_revision.recipe_version_id = new.recipe_version_id
            and successor_revision.recipe_line_id = prior_revision.recipe_line_id
            and successor_revision.predecessor_recipe_line_revision_id = prior_revision.recipe_line_revision_id
            and successor_revision.line_disposition in ('PRESENT', 'REMOVED')
        )
    ) then
      raise exception using
        errcode = '23514',
        message = 'every previously present recipe line requires an explicit successor or removal';
    end if;

    if exists (
      select 1
      from atlas_admin.recipe_line_revisions successor_revision
      join atlas_admin.recipe_line_revisions prior_revision
        on prior_revision.recipe_line_revision_id = successor_revision.predecessor_recipe_line_revision_id
      where successor_revision.recipe_version_id = new.recipe_version_id
        and prior_revision.recipe_version_id <> new.predecessor_recipe_version_id
    ) then
      raise exception using
        errcode = '23514',
        message = 'recipe line successor is cross-wired to a non-predecessor version';
    end if;
  end if;

  if new.recipe_version_status = 'RELEASED_FOR_PLANNING'
    and new.predecessor_recipe_version_id is not null
  then
    select prior_version.recipe_version_status, prior_version.released_at
      into predecessor_status, predecessor_released_at
    from atlas_admin.recipe_versions prior_version
    where prior_version.recipe_version_id = new.predecessor_recipe_version_id;

    if predecessor_released_at is not null and predecessor_status <> 'LOCKED' then
      raise exception using
        errcode = '23514',
        message = 'a previously released predecessor must be locked with its successor release';
    end if;
  end if;

  return null;
end
$$;

create trigger recipes_immutable_scope_guard
before update on atlas_admin.recipes
for each row execute function atlas_admin.pa_06e_h0a2_recipe_version_lifecycle_guard();

create trigger recipe_versions_lifecycle_guard
before insert or update or delete on atlas_admin.recipe_versions
for each row execute function atlas_admin.pa_06e_h0a2_recipe_version_lifecycle_guard();

create trigger recipe_lines_immutable_ownership_guard
before update on atlas_admin.recipe_lines
for each row execute function atlas_admin.pa_06e_h0a2_recipe_line_revision_guard();

create trigger recipe_line_revisions_immutable_lineage_guard
before insert or update or delete on atlas_admin.recipe_line_revisions
for each row execute function atlas_admin.pa_06e_h0a2_recipe_line_revision_guard();

create constraint trigger recipe_versions_integrity_guard
after insert or update on atlas_admin.recipe_versions
deferrable initially deferred
for each row execute function atlas_admin.pa_06e_h0a2_recipe_version_integrity_guard();

comment on table atlas_admin.dishes is
  'Stable menu-selectable Dish references. Active normalized names are unique and inactive history remains retained.';
comment on table atlas_admin.recipes is
  'Stable Recipe roots scoped to one Dish and either no SchoolType (general) or one exact SchoolType.';
comment on table atlas_admin.recipe_versions is
  'Exact Recipe composition snapshots with DRAFT, VALIDATED, RELEASED_FOR_PLANNING, and LOCKED lifecycle evidence.';
comment on table atlas_admin.recipe_lines is
  'Stable RecipeLine identities independent of ingredient, quantity, version position, or display order.';
comment on table atlas_admin.recipe_line_revisions is
  'Immutable exact BOM facts and one-to-one correction/removal lineage for one RecipeVersion and stable RecipeLine.';
comment on column atlas_admin.recipes.school_type_id is
  'Null selects the general Recipe scope; non-null selects one exact SchoolType Recipe scope. No fallback precedence is implied.';
comment on column atlas_admin.recipe_versions.basis_portions is
  'Explicit positive recipe basis. No hidden per-100-portions assumption is permitted.';
comment on column atlas_admin.recipe_line_revisions.predecessor_recipe_line_revision_id is
  'Exact one-to-one predecessor on the same Recipe and stable RecipeLine in the RecipeVersion predecessor.';
comment on column atlas_admin.recipe_line_revisions.calculation_kind is
  'H0A2 is fixed to proportional-per-basis facts and adds no formula or special-case calculation engine.';

alter table atlas_admin.dishes enable row level security;
alter table atlas_admin.dishes force row level security;
alter table atlas_admin.recipes enable row level security;
alter table atlas_admin.recipes force row level security;
alter table atlas_admin.recipe_versions enable row level security;
alter table atlas_admin.recipe_versions force row level security;
alter table atlas_admin.recipe_lines enable row level security;
alter table atlas_admin.recipe_lines force row level security;
alter table atlas_admin.recipe_line_revisions enable row level security;
alter table atlas_admin.recipe_line_revisions force row level security;

revoke all on table atlas_admin.dishes from public, anon, authenticated, service_role;
revoke all on table atlas_admin.recipes from public, anon, authenticated, service_role;
revoke all on table atlas_admin.recipe_versions from public, anon, authenticated, service_role;
revoke all on table atlas_admin.recipe_lines from public, anon, authenticated, service_role;
revoke all on table atlas_admin.recipe_line_revisions from public, anon, authenticated, service_role;

revoke execute on function atlas_admin.pa_06e_h0a2_recipe_version_lifecycle_guard()
  from public, anon, authenticated, service_role;
revoke execute on function atlas_admin.pa_06e_h0a2_recipe_line_revision_guard()
  from public, anon, authenticated, service_role;
revoke execute on function atlas_admin.pa_06e_h0a2_recipe_version_integrity_guard()
  from public, anon, authenticated, service_role;

reset role;
