-- RMVP-02B: typed Recipe composition adjustment rules, deterministic
-- effective BOM resolution, preview, correction lineage, and controlled
-- one-way OPS v1 snapshot import.
--
-- The two private relations below are the complete adjustment persistence
-- boundary. Planning facts and immutable Recipe/BOM facts are not modified.

set role atlas_owner;

create table atlas_admin.recipe_composition_adjustments (
  recipe_composition_adjustment_id uuid not null default gen_random_uuid(),
  scope_kind text not null,
  action_kind text not null,
  school_id uuid,
  dish_id uuid,
  school_type_id uuid,
  target_ingredient_id uuid,
  target_recipe_line_id uuid,
  adjustment_line_id uuid,
  current_revision_id uuid,
  current_revision_number integer not null default 0,
  lifecycle_status text not null default 'ACTIVE',
  version bigint not null default 1,
  legacy_source text,
  legacy_record_id text,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  updated_by_actor_id uuid not null,
  updated_at timestamptz not null default transaction_timestamp(),
  constraint recipe_composition_adjustments_pkey primary key (
    recipe_composition_adjustment_id
  ),
  constraint recipe_composition_adjustments_identity_key unique (
    recipe_composition_adjustment_id,
    scope_kind,
    action_kind
  ),
  constraint recipe_composition_adjustments_school_fkey foreign key (
    school_id
  ) references atlas_admin.schools (school_id) on delete restrict,
  constraint recipe_composition_adjustments_dish_fkey foreign key (
    dish_id
  ) references atlas_admin.dishes (dish_id) on delete restrict,
  constraint recipe_composition_adjustments_school_type_fkey foreign key (
    school_type_id
  ) references atlas_admin.school_types (school_type_id) on delete restrict,
  constraint recipe_composition_adjustments_target_ingredient_fkey
    foreign key (target_ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint recipe_composition_adjustments_target_recipe_line_fkey
    foreign key (target_recipe_line_id)
    references atlas_admin.recipe_lines (recipe_line_id) on delete restrict,
  constraint recipe_composition_adjustments_created_by_fkey foreign key (
    created_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint recipe_composition_adjustments_updated_by_fkey foreign key (
    updated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint recipe_composition_adjustments_scope_check check (
    scope_kind in (
      'SYSTEM_INGREDIENT',
      'SYSTEM_DISH',
      'SCHOOL',
      'SCHOOL_DISH'
    )
  ),
  constraint recipe_composition_adjustments_action_check check (
    action_kind in ('ADD', 'REPLACE', 'ADJUST_QUANTITY', 'REMOVE')
  ),
  constraint recipe_composition_adjustments_scope_action_check check (
    (scope_kind = 'SYSTEM_INGREDIENT' and action_kind = 'REPLACE')
    or (
      scope_kind = 'SYSTEM_DISH'
      and action_kind in ('ADD', 'REPLACE', 'ADJUST_QUANTITY', 'REMOVE')
    )
    or (
      scope_kind = 'SCHOOL'
      and action_kind in ('REPLACE', 'REMOVE')
    )
    or (
      scope_kind = 'SCHOOL_DISH'
      and action_kind in ('ADD', 'REPLACE', 'ADJUST_QUANTITY', 'REMOVE')
    )
  ),
  constraint recipe_composition_adjustments_typed_scope_check check (
    (
      scope_kind = 'SYSTEM_INGREDIENT'
      and school_id is null
      and dish_id is null
      and school_type_id is null
      and target_ingredient_id is not null
      and target_recipe_line_id is null
      and adjustment_line_id is null
    )
    or (
      scope_kind = 'SYSTEM_DISH'
      and school_id is null
      and dish_id is not null
      and (
        (
          action_kind = 'ADD'
          and target_ingredient_id is not null
          and target_recipe_line_id is null
          and adjustment_line_id is not null
        )
        or (
          action_kind <> 'ADD'
          and target_ingredient_id is null
          and target_recipe_line_id is not null
          and adjustment_line_id is null
        )
      )
    )
    or (
      scope_kind = 'SCHOOL'
      and school_id is not null
      and dish_id is null
      and school_type_id is null
      and target_ingredient_id is not null
      and target_recipe_line_id is null
      and adjustment_line_id is null
    )
    or (
      scope_kind = 'SCHOOL_DISH'
      and school_id is not null
      and dish_id is not null
      and school_type_id is null
      and (
        (
          action_kind = 'ADD'
          and target_ingredient_id is not null
          and target_recipe_line_id is null
          and adjustment_line_id is not null
        )
        or (
          action_kind <> 'ADD'
          and target_ingredient_id is null
          and target_recipe_line_id is not null
          and adjustment_line_id is null
        )
      )
    )
  ),
  constraint recipe_composition_adjustments_lifecycle_check check (
    lifecycle_status in ('ACTIVE', 'SUPERSEDED', 'CANCELLED')
  ),
  constraint recipe_composition_adjustments_revision_check check (
    (
      current_revision_number = 0
      and current_revision_id is null
    )
    or (
      current_revision_number > 0
      and current_revision_id is not null
    )
  ),
  constraint recipe_composition_adjustments_version_check check (version > 0),
  constraint recipe_composition_adjustments_legacy_check check (
    (legacy_source is null and legacy_record_id is null)
    or (
      btrim(legacy_source) <> ''
      and btrim(legacy_record_id) <> ''
    )
  )
);

create table atlas_admin.recipe_composition_adjustment_revisions (
  recipe_composition_adjustment_revision_id uuid not null
    default gen_random_uuid(),
  recipe_composition_adjustment_id uuid not null,
  scope_kind text not null,
  action_kind text not null,
  revision_number integer not null,
  predecessor_revision_id uuid,
  revision_status text not null default 'ACTIVE',
  effective_from date not null,
  effective_to date,
  substitute_ingredient_id uuid,
  quantity_per_basis numeric(20, 6),
  unit_id uuid,
  reason_code text not null,
  reason_note text not null,
  source_evidence jsonb not null default '{}'::jsonb,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint recipe_composition_adjustment_revisions_pkey primary key (
    recipe_composition_adjustment_revision_id
  ),
  constraint recipe_composition_adjustment_revisions_id_owner_key unique (
    recipe_composition_adjustment_revision_id,
    recipe_composition_adjustment_id
  ),
  constraint recipe_composition_adjustment_revisions_adjustment_fkey
    foreign key (
      recipe_composition_adjustment_id,
      scope_kind,
      action_kind
    ) references atlas_admin.recipe_composition_adjustments (
      recipe_composition_adjustment_id,
      scope_kind,
      action_kind
    ) on delete restrict,
  constraint recipe_composition_adjustment_revisions_predecessor_fkey
    foreign key (
      predecessor_revision_id,
      recipe_composition_adjustment_id
    ) references atlas_admin.recipe_composition_adjustment_revisions (
      recipe_composition_adjustment_revision_id,
      recipe_composition_adjustment_id
    ) on delete restrict,
  constraint recipe_composition_adjustment_revisions_substitute_fkey
    foreign key (substitute_ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint recipe_composition_adjustment_revisions_unit_fkey foreign key (
    unit_id
  ) references atlas_admin.units (unit_id) on delete restrict,
  constraint recipe_composition_adjustment_revisions_actor_fkey foreign key (
    created_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint recipe_composition_adjustment_revisions_number_key unique (
    recipe_composition_adjustment_id,
    revision_number
  ),
  constraint recipe_composition_adjustment_revisions_predecessor_key unique (
    predecessor_revision_id
  ),
  constraint recipe_composition_adjustment_revisions_number_check check (
    revision_number > 0
  ),
  constraint recipe_composition_adjustment_revisions_predecessor_check check (
    (
      revision_number = 1
      and predecessor_revision_id is null
    )
    or (
      revision_number > 1
      and predecessor_revision_id is not null
      and predecessor_revision_id
        <> recipe_composition_adjustment_revision_id
    )
  ),
  constraint recipe_composition_adjustment_revisions_status_check check (
    revision_status in ('ACTIVE', 'SUPERSEDED', 'CANCELLED')
  ),
  constraint recipe_composition_adjustment_revisions_period_check check (
    effective_to is null or effective_to > effective_from
  ),
  constraint recipe_composition_adjustment_revisions_reason_check check (
    btrim(reason_code) <> ''
    and btrim(reason_note) <> ''
  ),
  constraint recipe_composition_adjustment_revisions_source_check check (
    jsonb_typeof(source_evidence) = 'object'
  ),
  constraint recipe_composition_adjustment_revisions_payload_check check (
    (
      revision_status = 'CANCELLED'
      and substitute_ingredient_id is null
      and quantity_per_basis is null
      and unit_id is null
    )
    or (
      revision_status <> 'CANCELLED'
      and (
        (
          action_kind = 'REPLACE'
          and substitute_ingredient_id is not null
          and (
            (
              quantity_per_basis is null
              and unit_id is null
            )
            or (
              quantity_per_basis > 0
              and unit_id is not null
            )
          )
        )
        or (
          action_kind = 'ADJUST_QUANTITY'
          and substitute_ingredient_id is null
          and quantity_per_basis > 0
          and unit_id is null
        )
        or (
          action_kind = 'ADD'
          and substitute_ingredient_id is null
          and quantity_per_basis > 0
          and unit_id is not null
        )
        or (
          action_kind = 'REMOVE'
          and substitute_ingredient_id is null
          and quantity_per_basis is null
          and unit_id is null
        )
      )
    )
  )
);

alter table atlas_admin.recipe_composition_adjustments
  add constraint recipe_composition_adjustments_current_revision_fkey
  foreign key (
    current_revision_id,
    recipe_composition_adjustment_id
  ) references atlas_admin.recipe_composition_adjustment_revisions (
    recipe_composition_adjustment_revision_id,
    recipe_composition_adjustment_id
  ) on delete restrict deferrable initially deferred;

create unique index recipe_composition_adjustments_legacy_source_key
  on atlas_admin.recipe_composition_adjustments (
    legacy_source,
    legacy_record_id
  )
  where legacy_source is not null;
create index recipe_composition_adjustments_scope_lifecycle_idx
  on atlas_admin.recipe_composition_adjustments (
    scope_kind,
    lifecycle_status,
    dish_id,
    school_id
  );
create index recipe_composition_adjustments_target_ingredient_idx
  on atlas_admin.recipe_composition_adjustments (target_ingredient_id)
  where target_ingredient_id is not null;
create index recipe_composition_adjustments_target_recipe_line_idx
  on atlas_admin.recipe_composition_adjustments (target_recipe_line_id)
  where target_recipe_line_id is not null;
create index recipe_composition_adjustments_school_type_idx
  on atlas_admin.recipe_composition_adjustments (school_type_id)
  where school_type_id is not null;
create index recipe_composition_adjustment_revisions_effective_idx
  on atlas_admin.recipe_composition_adjustment_revisions (
    effective_from,
    effective_to,
    recipe_composition_adjustment_id
  );
create index recipe_composition_adjustment_revisions_actor_idx
  on atlas_admin.recipe_composition_adjustment_revisions (
    created_by_actor_id
  );

create or replace function atlas_core.rmvp_02b_guard_adjustment_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_table_name = 'recipe_composition_adjustment_revisions' then
    raise exception using
      errcode = '23514',
      message = 'accepted Recipe composition adjustment revisions are immutable and cannot be deleted';
  end if;
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'Recipe composition adjustment roots cannot be deleted';
  end if;
  if new.recipe_composition_adjustment_id
       is distinct from old.recipe_composition_adjustment_id
     or new.scope_kind is distinct from old.scope_kind
     or new.action_kind is distinct from old.action_kind
     or new.school_id is distinct from old.school_id
     or new.dish_id is distinct from old.dish_id
     or new.school_type_id is distinct from old.school_type_id
     or new.target_ingredient_id is distinct from old.target_ingredient_id
     or new.target_recipe_line_id is distinct from old.target_recipe_line_id
     or new.adjustment_line_id is distinct from old.adjustment_line_id
     or new.legacy_source is distinct from old.legacy_source
     or new.legacy_record_id is distinct from old.legacy_record_id
     or new.created_by_actor_id is distinct from old.created_by_actor_id
     or new.created_at is distinct from old.created_at then
    raise exception using
      errcode = '23514',
      message = 'Recipe composition adjustment identity and creation evidence are immutable';
  end if;
  return new;
end;
$$;

create trigger recipe_composition_adjustments_immutable_identity
before update or delete
on atlas_admin.recipe_composition_adjustments
for each row execute function atlas_core.rmvp_02b_guard_adjustment_history();

create trigger recipe_composition_adjustment_revisions_immutable
before update or delete
on atlas_admin.recipe_composition_adjustment_revisions
for each row execute function atlas_core.rmvp_02b_guard_adjustment_history();

alter table atlas_admin.recipe_composition_adjustments
  enable row level security;
alter table atlas_admin.recipe_composition_adjustments
  force row level security;
alter table atlas_admin.recipe_composition_adjustment_revisions
  enable row level security;
alter table atlas_admin.recipe_composition_adjustment_revisions
  force row level security;

comment on table atlas_admin.recipe_composition_adjustments is
  'RMVP-02B stable typed Recipe composition adjustment identity and mutable optimistic-concurrency control root.';
comment on table atlas_admin.recipe_composition_adjustment_revisions is
  'RMVP-02B immutable accepted active, successor, or cancellation evidence; prior lifecycle is derived from the root current pointer.';

reset role;

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values
  (
    'master_data.recipe_adjustments.read',
    'Read Recipe adjustment rules and effective BOM',
    'ADMIN',
    'ACTIVE'
  ),
  (
    'master_data.recipe_adjustments.write',
    'Create and supersede Recipe adjustment rules',
    'ADMIN',
    'ACTIVE'
  ),
  (
    'master_data.recipe_adjustments.cancel',
    'Cancel Recipe adjustment rules',
    'ADMIN',
    'ACTIVE'
  );

create or replace function atlas_core.rmvp_02b_safe_date(value text)
returns date
language plpgsql
stable
set search_path = ''
as $$
begin
  return value::date;
exception when others then
  return null;
end;
$$;

create or replace function atlas_core.rmvp_02b_read_error(
  request jsonb,
  read_name text,
  error_code text,
  safe_message text,
  field_errors jsonb default '[]'::jsonb,
  blocking_references jsonb default '[]'::jsonb
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RMVP-02B.v1',
    'error_code', error_code,
    'safe_message', safe_message,
    'domain', 'ADMIN',
    'read_name', read_name,
    'field_errors', coalesce(field_errors, '[]'::jsonb),
    'blocking_references', coalesce(blocking_references, '[]'::jsonb),
    'correlation_id', request ->> 'correlation_id'
  );
$$;

create or replace function atlas_core.rmvp_02b_validate_read_request(
  request jsonb,
  read_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_02b_read_error(
      coalesce(request, '{}'::jsonb),
      read_name,
      'VALIDATION_FAILED',
      'The read request must be a JSON object.'
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-02B.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use RMVP-02B.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'correlation_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if request -> 'payload' is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'A JSON object is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_02b_read_error(
      request,
      read_name,
      'VALIDATION_FAILED',
      'The read envelope is invalid.',
      v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_core.rmvp_02b_validate_command_request(
  request jsonb,
  command_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
  v_requested_at timestamptz;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb),
      'VALIDATION_FAILED',
      'The command request must be a JSON object.',
      'ADMIN',
      command_name
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-02B.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use RMVP-02B.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'command_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'correlation_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
     or pg_catalog.length(request ->> 'idempotency_key') > 200 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'idempotency_key',
        'message', 'A non-empty key of at most 200 characters is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_version',
        'message', 'A positive integer version is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(
    request ->> 'requested_at'
  );
  if v_requested_at is null
     or v_requested_at > pg_catalog.transaction_timestamp() then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_at',
        'message', 'A valid non-future timestamp is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = ''
     or pg_catalog.btrim(coalesce(request ->> 'reason_note', '')) = '' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason',
        'message', 'A reason code and non-empty reason note are required.'
      )
    );
  end if;
  if request -> 'payload' is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'A JSON object is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The command envelope is invalid.',
      'ADMIN',
      command_name,
      false,
      v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_core.rmvp_02b_prepare_command(
  request jsonb,
  command_name text,
  capability_code text,
  aggregate_scope text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
begin
  v_error := atlas_core.rmvp_02b_validate_command_request(
    request,
    command_name
  );
  if v_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_error
    );
  end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    capability_code,
    command_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_context -> 'error'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    command_name,
    'ADMIN',
    aggregate_scope
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_begin -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY',
    'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

create or replace function atlas_core.rmvp_02b_adjustment_workbench_payload()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'scope_catalog',
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'scope_kind', 'SYSTEM_INGREDIENT',
        'actions', pg_catalog.jsonb_build_array('REPLACE')
      ),
      pg_catalog.jsonb_build_object(
        'scope_kind', 'SYSTEM_DISH',
        'actions', pg_catalog.jsonb_build_array(
          'ADD', 'REPLACE', 'ADJUST_QUANTITY', 'REMOVE'
        )
      ),
      pg_catalog.jsonb_build_object(
        'scope_kind', 'SCHOOL',
        'actions', pg_catalog.jsonb_build_array('REPLACE', 'REMOVE')
      ),
      pg_catalog.jsonb_build_object(
        'scope_kind', 'SCHOOL_DISH',
        'actions', pg_catalog.jsonb_build_array(
          'ADD', 'REPLACE', 'ADJUST_QUANTITY', 'REMOVE'
        )
      )
    ),
    'precedence',
    pg_catalog.jsonb_build_array(
      'RELEASED_RECIPE_VERSION',
      'SYSTEM_INGREDIENT',
      'SYSTEM_DISH',
      'SCHOOL',
      'SCHOOL_DISH'
    ),
    'schools',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'school_id', school.school_id,
            'school_code', school.school_code,
            'school_name', school.school_name,
            'school_type_id', school.school_type_id,
            'school_status', school.school_status,
            'version', school.version
          )
          order by school.display_order, school.school_name, school.school_id
        )
        from atlas_admin.schools school
      ),
      '[]'::jsonb
    ),
    'dishes',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_id', dish.dish_id,
            'dish_code', dish.dish_code,
            'dish_name', dish.dish_name,
            'dish_status', dish.dish_status,
            'requires_need_generation', dish.requires_need_generation,
            'version', dish.version
          )
          order by dish.display_order, dish.dish_name, dish.dish_id
        )
        from atlas_admin.dishes dish
      ),
      '[]'::jsonb
    ),
    'school_types',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'school_type_id', school_type.school_type_id,
            'school_type_code', school_type.school_type_code,
            'school_type_name', school_type.school_type_name,
            'school_type_status', school_type.school_type_status
          )
          order by school_type.school_type_name, school_type.school_type_id
        )
        from atlas_admin.school_types school_type
      ),
      '[]'::jsonb
    ),
    'ingredients',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'ingredient_id', ingredient.ingredient_id,
            'ingredient_code', ingredient.ingredient_code,
            'ingredient_name', ingredient.ingredient_name,
            'ingredient_status', ingredient.ingredient_status
          )
          order by ingredient.ingredient_name, ingredient.ingredient_id
        )
        from atlas_admin.ingredients ingredient
      ),
      '[]'::jsonb
    ),
    'units',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'unit_id', unit.unit_id,
            'unit_code', unit.unit_code,
            'unit_name', unit.unit_name,
            'unit_status', unit.unit_status
          )
          order by unit.unit_name, unit.unit_id
        )
        from atlas_admin.units unit
      ),
      '[]'::jsonb
    ),
    'recipe_lines',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'recipe_line_id', line.recipe_line_id,
            'recipe_id', line.recipe_id,
            'dish_id', recipe.dish_id,
            'school_type_id', recipe.school_type_id,
            'line_code', line.line_code
          )
          order by recipe.dish_id, line.line_code nulls last,
            line.recipe_line_id
        )
        from atlas_admin.recipe_lines line
        join atlas_admin.recipes recipe
          on recipe.recipe_id = line.recipe_id
      ),
      '[]'::jsonb
    ),
    'adjustments',
    coalesce(
      (
        select pg_catalog.jsonb_agg(adjustment.payload order by
          adjustment.created_at,
          adjustment.recipe_composition_adjustment_id
        )
        from (
          select
            root.recipe_composition_adjustment_id,
            root.created_at,
            pg_catalog.jsonb_build_object(
              'adjustment_id', root.recipe_composition_adjustment_id,
              'scope_kind', root.scope_kind,
              'action_kind', root.action_kind,
              'school_id', root.school_id,
              'dish_id', root.dish_id,
              'school_type_id', root.school_type_id,
              'target_ingredient_id', root.target_ingredient_id,
              'target_recipe_line_id', root.target_recipe_line_id,
              'adjustment_line_id', root.adjustment_line_id,
              'current_revision_id', root.current_revision_id,
              'current_revision_number', root.current_revision_number,
              'lifecycle_status', root.lifecycle_status,
              'version', root.version,
              'legacy_source', root.legacy_source,
              'legacy_record_id', root.legacy_record_id,
              'created_by_actor_id', root.created_by_actor_id,
              'created_by_actor_name', creator.display_name,
              'created_at', root.created_at,
              'updated_by_actor_id', root.updated_by_actor_id,
              'updated_by_actor_name', updater.display_name,
              'updated_at', root.updated_at,
              'revisions',
              coalesce(
                (
                  select pg_catalog.jsonb_agg(
                    pg_catalog.jsonb_build_object(
                      'revision_id',
                        revision.recipe_composition_adjustment_revision_id,
                      'revision_number', revision.revision_number,
                      'predecessor_revision_id',
                        revision.predecessor_revision_id,
                      'lifecycle_status',
                        case
                          when revision.recipe_composition_adjustment_revision_id
                               = root.current_revision_id
                            then root.lifecycle_status
                          else 'SUPERSEDED'
                        end,
                      'effective_from', revision.effective_from,
                      'effective_to', revision.effective_to,
                      'substitute_ingredient_id',
                        revision.substitute_ingredient_id,
                      'quantity_per_basis', revision.quantity_per_basis,
                      'unit_id', revision.unit_id,
                      'reason_code', revision.reason_code,
                      'reason_note', revision.reason_note,
                      'source_evidence', revision.source_evidence,
                      'created_by_actor_id', revision.created_by_actor_id,
                      'created_by_actor_name', revision_actor.display_name,
                      'created_at', revision.created_at
                    )
                    order by revision.revision_number
                  )
                  from atlas_admin.recipe_composition_adjustment_revisions
                    revision
                  join atlas_core.actors revision_actor
                    on revision_actor.actor_id =
                      revision.created_by_actor_id
                  where revision.recipe_composition_adjustment_id =
                    root.recipe_composition_adjustment_id
                ),
                '[]'::jsonb
              )
            ) as payload
          from atlas_admin.recipe_composition_adjustments root
          join atlas_core.actors creator
            on creator.actor_id = root.created_by_actor_id
          join atlas_core.actors updater
            on updater.actor_id = root.updated_by_actor_id
        ) adjustment
      ),
      '[]'::jsonb
    )
  );
$$;

create or replace function atlas_core.rmvp_02b_active_rules(
  target_as_of_date date,
  target_school_id uuid,
  target_dish_id uuid,
  proposed_adjustment jsonb default null,
  excluded_adjustment_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_school_type_id uuid;
  v_rules jsonb;
  v_proposal_from date;
  v_proposal_to date;
  v_scope text;
  v_applies boolean := false;
begin
  if target_school_id is not null then
    select school.school_type_id
    into v_school_type_id
    from atlas_admin.schools school
    where school.school_id = target_school_id;
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'adjustment_id', root.recipe_composition_adjustment_id,
        'revision_id',
          revision.recipe_composition_adjustment_revision_id,
        'revision_number', revision.revision_number,
        'scope_kind', root.scope_kind,
        'action_kind', root.action_kind,
        'school_id', root.school_id,
        'dish_id', root.dish_id,
        'school_type_id', root.school_type_id,
        'target_ingredient_id', root.target_ingredient_id,
        'target_recipe_line_id', root.target_recipe_line_id,
        'adjustment_line_id', root.adjustment_line_id,
        'substitute_ingredient_id', revision.substitute_ingredient_id,
        'quantity_per_basis', revision.quantity_per_basis,
        'unit_id', revision.unit_id,
        'reason_code', revision.reason_code,
        'reason_note', revision.reason_note,
        'effective_from', revision.effective_from,
        'effective_to', revision.effective_to,
        'source_evidence', revision.source_evidence,
        'created_by_actor_id', revision.created_by_actor_id,
        'created_by_actor_name', actor.display_name,
        'is_preview', false
      )
      order by
        case root.scope_kind
          when 'SYSTEM_INGREDIENT' then 1
          when 'SYSTEM_DISH' then 2
          when 'SCHOOL' then 3
          when 'SCHOOL_DISH' then 4
        end,
        root.recipe_composition_adjustment_id
    ),
    '[]'::jsonb
  )
  into v_rules
  from atlas_admin.recipe_composition_adjustments root
  join lateral (
    select candidate.*
    from atlas_admin.recipe_composition_adjustment_revisions candidate
    where candidate.recipe_composition_adjustment_id =
        root.recipe_composition_adjustment_id
      and target_as_of_date >= candidate.effective_from
      and (
        candidate.effective_to is null
        or target_as_of_date < candidate.effective_to
      )
    order by candidate.revision_number desc
    limit 1
  ) revision on revision.revision_status = 'ACTIVE'
  join atlas_core.actors actor
    on actor.actor_id = revision.created_by_actor_id
  where (
      excluded_adjustment_id is null
      or root.recipe_composition_adjustment_id <> excluded_adjustment_id
    )
    and (
      root.scope_kind = 'SYSTEM_INGREDIENT'
      or (
        root.scope_kind = 'SYSTEM_DISH'
        and root.dish_id = target_dish_id
        and (
          root.school_type_id is null
          or (
            target_school_id is not null
            and root.school_type_id = v_school_type_id
          )
        )
      )
      or (
        root.scope_kind = 'SCHOOL'
        and target_school_id is not null
        and root.school_id = target_school_id
      )
      or (
        root.scope_kind = 'SCHOOL_DISH'
        and target_school_id is not null
        and root.school_id = target_school_id
        and root.dish_id = target_dish_id
      )
    );

  if proposed_adjustment is null
     or pg_catalog.jsonb_typeof(proposed_adjustment) <> 'object' then
    return v_rules;
  end if;

  v_proposal_from := atlas_core.rmvp_02b_safe_date(
    proposed_adjustment ->> 'effective_from'
  );
  v_proposal_to := atlas_core.rmvp_02b_safe_date(
    proposed_adjustment ->> 'effective_to'
  );
  if v_proposal_from is null
     or target_as_of_date < v_proposal_from
     or (
       v_proposal_to is not null
       and target_as_of_date >= v_proposal_to
     ) then
    return v_rules;
  end if;

  v_scope := proposed_adjustment ->> 'scope_kind';
  v_applies :=
    v_scope = 'SYSTEM_INGREDIENT'
    or (
      v_scope = 'SYSTEM_DISH'
      and atlas_core.pa_05b_safe_uuid(
        proposed_adjustment ->> 'dish_id'
      ) = target_dish_id
      and (
        atlas_core.pa_05b_safe_uuid(
          proposed_adjustment ->> 'school_type_id'
        ) is null
        or (
          target_school_id is not null
          and atlas_core.pa_05b_safe_uuid(
            proposed_adjustment ->> 'school_type_id'
          ) = v_school_type_id
        )
      )
    )
    or (
      v_scope = 'SCHOOL'
      and target_school_id is not null
      and atlas_core.pa_05b_safe_uuid(
        proposed_adjustment ->> 'school_id'
      ) = target_school_id
    )
    or (
      v_scope = 'SCHOOL_DISH'
      and target_school_id is not null
      and atlas_core.pa_05b_safe_uuid(
        proposed_adjustment ->> 'school_id'
      ) = target_school_id
      and atlas_core.pa_05b_safe_uuid(
        proposed_adjustment ->> 'dish_id'
      ) = target_dish_id
    );
  if not v_applies then return v_rules; end if;

  return v_rules || pg_catalog.jsonb_build_array(
    pg_catalog.jsonb_build_object(
      'adjustment_id', proposed_adjustment ->> 'adjustment_id',
      'revision_id', proposed_adjustment ->> 'revision_id',
      'revision_number',
        coalesce(
          atlas_core.pa_05b_safe_bigint(
            proposed_adjustment ->> 'revision_number'
          ),
          1
        ),
      'scope_kind', proposed_adjustment ->> 'scope_kind',
      'action_kind', proposed_adjustment ->> 'action_kind',
      'school_id', proposed_adjustment ->> 'school_id',
      'dish_id', proposed_adjustment ->> 'dish_id',
      'school_type_id', proposed_adjustment ->> 'school_type_id',
      'target_ingredient_id',
        proposed_adjustment ->> 'target_ingredient_id',
      'target_recipe_line_id',
        proposed_adjustment ->> 'target_recipe_line_id',
      'adjustment_line_id', proposed_adjustment ->> 'adjustment_line_id',
      'substitute_ingredient_id',
        proposed_adjustment ->> 'substitute_ingredient_id',
      'quantity_per_basis',
        atlas_core.pa_05b_safe_numeric(
          proposed_adjustment ->> 'quantity_per_basis'
        ),
      'unit_id', proposed_adjustment ->> 'unit_id',
      'reason_code', proposed_adjustment ->> 'reason_code',
      'reason_note', proposed_adjustment ->> 'reason_note',
      'effective_from', v_proposal_from,
      'effective_to', v_proposal_to,
      'source_evidence',
        coalesce(proposed_adjustment -> 'source_evidence', '{}'::jsonb),
      'created_by_actor_id', null,
      'created_by_actor_name', 'Xem trước',
      'is_preview', true
    )
  );
end;
$$;

create or replace function atlas_core.rmvp_02b_transform_line(
  source_line jsonb,
  applied_rule jsonb
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_action text := applied_rule ->> 'action_kind';
  v_before jsonb;
  v_after jsonb;
  v_result jsonb := source_line;
  v_quantity numeric := atlas_core.pa_05b_safe_numeric(
    applied_rule ->> 'quantity_per_basis'
  );
  v_step jsonb;
begin
  v_before := pg_catalog.jsonb_build_object(
    'ingredient_id', source_line ->> 'final_ingredient_id',
    'quantity_per_basis',
      atlas_core.pa_05b_safe_numeric(
        source_line ->> 'final_quantity_per_basis'
      ),
    'unit_id', source_line ->> 'final_unit_id',
    'disposition', source_line ->> 'final_disposition'
  );
  if v_action = 'REPLACE' then
    v_result := pg_catalog.jsonb_set(
      v_result,
      '{final_ingredient_id}',
      pg_catalog.to_jsonb(applied_rule ->> 'substitute_ingredient_id')
    );
    if v_quantity is not null then
      v_result := pg_catalog.jsonb_set(
        v_result,
        '{final_quantity_per_basis}',
        pg_catalog.to_jsonb(v_quantity)
      );
      v_result := pg_catalog.jsonb_set(
        v_result,
        '{final_unit_id}',
        pg_catalog.to_jsonb(applied_rule ->> 'unit_id')
      );
    end if;
  elsif v_action = 'ADJUST_QUANTITY' then
    v_result := pg_catalog.jsonb_set(
      v_result,
      '{final_quantity_per_basis}',
      pg_catalog.to_jsonb(v_quantity)
    );
  elsif v_action = 'REMOVE' then
    v_result := pg_catalog.jsonb_set(
      v_result,
      '{final_quantity_per_basis}',
      '0'::jsonb
    );
    v_result := pg_catalog.jsonb_set(
      v_result,
      '{final_disposition}',
      '"REMOVED"'::jsonb
    );
  end if;
  v_result := pg_catalog.jsonb_set(
    v_result,
    '{source_layer}',
    pg_catalog.to_jsonb(applied_rule ->> 'scope_kind')
  );
  v_after := pg_catalog.jsonb_build_object(
    'ingredient_id', v_result ->> 'final_ingredient_id',
    'quantity_per_basis',
      atlas_core.pa_05b_safe_numeric(
        v_result ->> 'final_quantity_per_basis'
      ),
    'unit_id', v_result ->> 'final_unit_id',
    'disposition', v_result ->> 'final_disposition'
  );
  v_step := pg_catalog.jsonb_build_object(
    'adjustment_id', applied_rule ->> 'adjustment_id',
    'revision_id', applied_rule ->> 'revision_id',
    'revision_number',
      atlas_core.pa_05b_safe_bigint(
        applied_rule ->> 'revision_number'
      ),
    'scope_kind', applied_rule ->> 'scope_kind',
    'action_kind', v_action,
    'before', v_before,
    'after', v_after,
    'reason_code', applied_rule ->> 'reason_code',
    'reason_note', applied_rule ->> 'reason_note',
    'effective_from', applied_rule ->> 'effective_from',
    'effective_to', applied_rule ->> 'effective_to',
    'is_preview', coalesce(
      (applied_rule ->> 'is_preview')::boolean,
      false
    )
  );
  v_result := pg_catalog.jsonb_set(
    v_result,
    '{applied_adjustment_ids}',
    coalesce(v_result -> 'applied_adjustment_ids', '[]'::jsonb)
      || pg_catalog.jsonb_build_array(applied_rule ->> 'adjustment_id')
  );
  v_result := pg_catalog.jsonb_set(
    v_result,
    '{applied_revision_ids}',
    coalesce(v_result -> 'applied_revision_ids', '[]'::jsonb)
      || pg_catalog.jsonb_build_array(applied_rule ->> 'revision_id')
  );
  v_result := pg_catalog.jsonb_set(
    v_result,
    '{lineage}',
    coalesce(v_result -> 'lineage', '[]'::jsonb)
      || pg_catalog.jsonb_build_array(v_step)
  );
  return v_result;
end;
$$;

create or replace function atlas_core.rmvp_02b_resolve_effective_composition(
  target_as_of_date date,
  target_school_id uuid,
  target_dish_id uuid,
  proposed_adjustment jsonb default null,
  excluded_adjustment_id uuid default null,
  historical_recipe_version_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_blockers jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_school atlas_admin.schools%rowtype;
  v_dish atlas_admin.dishes%rowtype;
  v_recipe_id uuid;
  v_recipe_version_id uuid;
  v_recipe_scope text;
  v_basis_portions integer;
  v_candidate_count bigint;
  v_historical boolean := historical_recipe_version_id is not null;
  v_rules jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_new_lines jsonb;
  v_line jsonb;
  v_rule jsonb;
  v_matching_count bigint;
  v_current_ingredient text;
  v_next_ingredient text;
  v_visited text[];
  v_found boolean;
  v_duplicate record;
  v_revision record;
begin
  if target_as_of_date is null or target_dish_id is null then
    return pg_catalog.jsonb_build_object(
      'status', 'BLOCKED',
      'as_of_date', target_as_of_date,
      'school_id', target_school_id,
      'dish_id', target_dish_id,
      'historical', v_historical,
      'selected_recipe', null,
      'lines', '[]'::jsonb,
      'warnings', '[]'::jsonb,
      'blockers', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'RESOLUTION_CONTEXT_REQUIRED',
          'message', 'An explicit date and Dish are required.'
        )
      )
    );
  end if;

  select * into v_dish
  from atlas_admin.dishes dish
  where dish.dish_id = target_dish_id;
  if not found then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'DISH_NOT_FOUND',
        'message', 'The selected Dish does not exist.'
      )
    );
  elsif v_dish.dish_status <> 'ACTIVE'
        or not v_dish.requires_need_generation then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'DISH_NOT_ELIGIBLE',
        'message',
          'The Dish must be active and require Need Generation.'
      )
    );
  end if;

  if target_school_id is not null then
    select * into v_school
    from atlas_admin.schools school
    where school.school_id = target_school_id;
    if not found then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'SCHOOL_NOT_FOUND',
          'message', 'The selected School does not exist.'
        )
      );
    elsif v_school.school_status <> 'ACTIVE' then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'SCHOOL_INACTIVE',
          'message', 'The selected School is not active.'
        )
      );
    end if;
  end if;

  if pg_catalog.jsonb_array_length(v_blockers) > 0 then
    return pg_catalog.jsonb_build_object(
      'status', 'BLOCKED',
      'as_of_date', target_as_of_date,
      'school_id', target_school_id,
      'dish_id', target_dish_id,
      'historical', v_historical,
      'selected_recipe', null,
      'lines', '[]'::jsonb,
      'warnings', v_warnings,
      'blockers', v_blockers
    );
  end if;

  if v_historical then
    select
      version.recipe_id,
      version.recipe_version_id,
      version.basis_portions,
      case
        when recipe.school_type_id is null then 'GENERAL'
        else 'SCHOOL_TYPE'
      end
    into
      v_recipe_id,
      v_recipe_version_id,
      v_basis_portions,
      v_recipe_scope
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe
      on recipe.recipe_id = version.recipe_id
    where version.recipe_version_id = historical_recipe_version_id
      and recipe.dish_id = target_dish_id
      and version.recipe_version_status in (
        'VALIDATED',
        'RELEASED_FOR_PLANNING',
        'LOCKED'
      );
    if not found then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'HISTORICAL_RECIPE_VERSION_NOT_FOUND',
          'message',
            'The named historical RecipeVersion is not a materialized version for this Dish.'
        )
      );
    else
      v_warnings := v_warnings || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'HISTORICAL_SUPPORT_RESOLUTION',
          'message',
            'This support result uses an explicitly named historical RecipeVersion and is not the current authoritative selection.'
        )
      );
    end if;
  else
    if target_school_id is not null
       and v_school.school_type_id is not null then
      select pg_catalog.count(*)
      into v_candidate_count
      from atlas_admin.recipes recipe
      join atlas_admin.recipe_versions version
        on version.recipe_id = recipe.recipe_id
       and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
      where recipe.dish_id = target_dish_id
        and recipe.school_type_id = v_school.school_type_id
        and recipe.recipe_status = 'ACTIVE';
    else
      v_candidate_count := 0;
    end if;
    if v_candidate_count > 1 then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'AMBIGUOUS_SCHOOL_TYPE_RECIPE',
          'message',
            'More than one eligible SchoolType Recipe was found.'
        )
      );
    elsif v_candidate_count = 1 then
      select recipe.recipe_id, version.recipe_version_id,
        version.basis_portions
      into v_recipe_id, v_recipe_version_id, v_basis_portions
      from atlas_admin.recipes recipe
      join atlas_admin.recipe_versions version
        on version.recipe_id = recipe.recipe_id
       and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
      where recipe.dish_id = target_dish_id
        and recipe.school_type_id = v_school.school_type_id
        and recipe.recipe_status = 'ACTIVE';
      v_recipe_scope := 'SCHOOL_TYPE';
    else
      select pg_catalog.count(*)
      into v_candidate_count
      from atlas_admin.recipes recipe
      join atlas_admin.recipe_versions version
        on version.recipe_id = recipe.recipe_id
       and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
      where recipe.dish_id = target_dish_id
        and recipe.school_type_id is null
        and recipe.recipe_status = 'ACTIVE';
      if v_candidate_count > 1 then
        v_blockers := v_blockers || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', 'AMBIGUOUS_GENERAL_RECIPE',
            'message', 'More than one eligible general Recipe was found.'
          )
        );
      elsif v_candidate_count = 0 then
        v_blockers := v_blockers || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', 'RECIPE_SELECTION_BLOCKED',
            'message',
              'No eligible released SchoolType or general Recipe was found.'
          )
        );
      else
        select recipe.recipe_id, version.recipe_version_id,
          version.basis_portions
        into v_recipe_id, v_recipe_version_id, v_basis_portions
        from atlas_admin.recipes recipe
        join atlas_admin.recipe_versions version
          on version.recipe_id = recipe.recipe_id
         and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
        where recipe.dish_id = target_dish_id
          and recipe.school_type_id is null
          and recipe.recipe_status = 'ACTIVE';
        v_recipe_scope := 'GENERAL';
      end if;
    end if;
  end if;

  if pg_catalog.jsonb_array_length(v_blockers) > 0 then
    return pg_catalog.jsonb_build_object(
      'status', 'BLOCKED',
      'as_of_date', target_as_of_date,
      'school_id', target_school_id,
      'dish_id', target_dish_id,
      'historical', v_historical,
      'selected_recipe', null,
      'lines', '[]'::jsonb,
      'warnings', v_warnings,
      'blockers', v_blockers
    );
  end if;

  for v_revision in
    select
      revision.recipe_line_revision_id,
      revision.recipe_line_id,
      revision.ingredient_id,
      revision.quantity_per_basis,
      revision.unit_id,
      revision.line_disposition,
      line.line_code
    from atlas_admin.recipe_line_revisions revision
    join atlas_admin.recipe_lines line
      on line.recipe_line_id = revision.recipe_line_id
    where revision.recipe_version_id = v_recipe_version_id
    order by line.line_code nulls last, revision.recipe_line_id
  loop
    v_lines := v_lines || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'selected_dish_id', target_dish_id,
        'selected_recipe_id', v_recipe_id,
        'selected_recipe_version_id', v_recipe_version_id,
        'basis_portions', v_basis_portions,
        'base_recipe_line_id', v_revision.recipe_line_id,
        'base_recipe_line_revision_id',
          v_revision.recipe_line_revision_id,
        'adjustment_line_id', null,
        'line_code', v_revision.line_code,
        'base_ingredient_id', v_revision.ingredient_id,
        'base_quantity_per_basis', v_revision.quantity_per_basis,
        'base_unit_id', v_revision.unit_id,
        'base_disposition', v_revision.line_disposition,
        'final_ingredient_id', v_revision.ingredient_id,
        'final_quantity_per_basis', v_revision.quantity_per_basis,
        'final_unit_id', v_revision.unit_id,
        'final_disposition', v_revision.line_disposition,
        'source_layer', 'RELEASED_RECIPE_VERSION',
        'applied_adjustment_ids', '[]'::jsonb,
        'applied_revision_ids', '[]'::jsonb,
        'lineage', '[]'::jsonb
      )
    );
  end loop;

  v_rules := atlas_core.rmvp_02b_active_rules(
    target_as_of_date,
    target_school_id,
    target_dish_id,
    proposed_adjustment,
    excluded_adjustment_id
  );

  -- SYSTEM_INGREDIENT is the only recursive layer. It resolves to the
  -- deterministic terminal Ingredient and records every hop.
  v_new_lines := '[]'::jsonb;
  for v_line in
    select value from pg_catalog.jsonb_array_elements(v_lines)
  loop
    if v_line ->> 'final_disposition' = 'PRESENT' then
      v_current_ingredient := v_line ->> 'final_ingredient_id';
      v_visited := array[v_current_ingredient];
      loop
        select pg_catalog.count(*)
        into v_matching_count
        from pg_catalog.jsonb_array_elements(v_rules) item
        where item ->> 'scope_kind' = 'SYSTEM_INGREDIENT'
          and item ->> 'target_ingredient_id' = v_current_ingredient;
        exit when v_matching_count = 0;
        if v_matching_count > 1 then
          v_blockers := v_blockers || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'code', 'AMBIGUOUS_SYSTEM_INGREDIENT_REPLACEMENT',
              'message',
                'More than one effective system replacement targets the same Ingredient.',
              'ingredient_id', v_current_ingredient
            )
          );
          exit;
        end if;
        select item into v_rule
        from pg_catalog.jsonb_array_elements(v_rules) item
        where item ->> 'scope_kind' = 'SYSTEM_INGREDIENT'
          and item ->> 'target_ingredient_id' = v_current_ingredient;
        v_next_ingredient := v_rule ->> 'substitute_ingredient_id';
        if v_next_ingredient = any(v_visited) then
          v_blockers := v_blockers || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'code', 'REPLACEMENT_CYCLE',
              'message',
                'The system Ingredient replacement chain contains a cycle.',
              'ingredient_chain',
                pg_catalog.to_jsonb(v_visited || v_next_ingredient)
            )
          );
          exit;
        end if;
        v_line := atlas_core.rmvp_02b_transform_line(v_line, v_rule);
        v_current_ingredient := v_next_ingredient;
        v_visited := v_visited || v_current_ingredient;
      end loop;
    end if;
    v_new_lines := v_new_lines || pg_catalog.jsonb_build_array(v_line);
  end loop;
  v_lines := v_new_lines;

  -- SYSTEM_DISH line changes and additions.
  for v_rule in
    select item
    from pg_catalog.jsonb_array_elements(v_rules) item
    where item ->> 'scope_kind' = 'SYSTEM_DISH'
    order by item ->> 'adjustment_id'
  loop
    if v_rule ->> 'action_kind' = 'ADD' then
      v_lines := v_lines || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'selected_dish_id', target_dish_id,
          'selected_recipe_id', v_recipe_id,
          'selected_recipe_version_id', v_recipe_version_id,
          'basis_portions', v_basis_portions,
          'base_recipe_line_id', null,
          'base_recipe_line_revision_id', null,
          'adjustment_line_id', v_rule ->> 'adjustment_line_id',
          'line_code', null,
          'base_ingredient_id', null,
          'base_quantity_per_basis', null,
          'base_unit_id', null,
          'base_disposition', null,
          'final_ingredient_id', v_rule ->> 'target_ingredient_id',
          'final_quantity_per_basis',
            atlas_core.pa_05b_safe_numeric(
              v_rule ->> 'quantity_per_basis'
            ),
          'final_unit_id', v_rule ->> 'unit_id',
          'final_disposition', 'PRESENT',
          'source_layer', 'SYSTEM_DISH',
          'applied_adjustment_ids',
            pg_catalog.jsonb_build_array(v_rule ->> 'adjustment_id'),
          'applied_revision_ids',
            pg_catalog.jsonb_build_array(v_rule ->> 'revision_id'),
          'lineage',
            pg_catalog.jsonb_build_array(
              pg_catalog.jsonb_build_object(
                'adjustment_id', v_rule ->> 'adjustment_id',
                'revision_id', v_rule ->> 'revision_id',
                'revision_number',
                  atlas_core.pa_05b_safe_bigint(
                    v_rule ->> 'revision_number'
                  ),
                'scope_kind', 'SYSTEM_DISH',
                'action_kind', 'ADD',
                'before', null,
                'after', pg_catalog.jsonb_build_object(
                  'ingredient_id', v_rule ->> 'target_ingredient_id',
                  'quantity_per_basis',
                    atlas_core.pa_05b_safe_numeric(
                      v_rule ->> 'quantity_per_basis'
                    ),
                  'unit_id', v_rule ->> 'unit_id',
                  'disposition', 'PRESENT'
                ),
                'reason_code', v_rule ->> 'reason_code',
                'reason_note', v_rule ->> 'reason_note',
                'effective_from', v_rule ->> 'effective_from',
                'effective_to', v_rule ->> 'effective_to',
                'is_preview',
                  coalesce((v_rule ->> 'is_preview')::boolean, false)
              )
            )
        )
      );
    else
      v_found := false;
      v_new_lines := '[]'::jsonb;
      for v_line in
        select value from pg_catalog.jsonb_array_elements(v_lines)
      loop
        if v_line ->> 'base_recipe_line_id'
             = v_rule ->> 'target_recipe_line_id' then
          v_found := true;
          if v_line ->> 'final_disposition' = 'PRESENT' then
            v_line := atlas_core.rmvp_02b_transform_line(v_line, v_rule);
          else
            v_blockers := v_blockers || pg_catalog.jsonb_build_array(
              pg_catalog.jsonb_build_object(
                'code', 'TARGET_NOT_APPLICABLE',
                'message',
                  'A SYSTEM_DISH target RecipeLine is no longer present.',
                'adjustment_id', v_rule ->> 'adjustment_id',
                'recipe_line_id', v_rule ->> 'target_recipe_line_id'
              )
            );
          end if;
        end if;
        v_new_lines := v_new_lines || pg_catalog.jsonb_build_array(v_line);
      end loop;
      if not v_found then
        v_blockers := v_blockers || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', 'TARGET_NOT_APPLICABLE',
            'message',
              'A SYSTEM_DISH target RecipeLine is not in the selected RecipeVersion.',
            'adjustment_id', v_rule ->> 'adjustment_id',
            'recipe_line_id', v_rule ->> 'target_recipe_line_id'
          )
        );
      end if;
      v_lines := v_new_lines;
    end if;
  end loop;

  -- SCHOOL rules target Ingredient identity after all system layers and are
  -- applied once, not recursively.
  v_new_lines := '[]'::jsonb;
  for v_line in
    select value from pg_catalog.jsonb_array_elements(v_lines)
  loop
    if v_line ->> 'final_disposition' = 'PRESENT' then
      select pg_catalog.count(*)
      into v_matching_count
      from pg_catalog.jsonb_array_elements(v_rules) item
      where item ->> 'scope_kind' = 'SCHOOL'
        and item ->> 'target_ingredient_id'
          = v_line ->> 'final_ingredient_id';
      if v_matching_count > 1 then
        v_blockers := v_blockers || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', 'AMBIGUOUS_SCHOOL_ADJUSTMENT',
            'message',
              'More than one effective School rule targets the same Ingredient.',
            'ingredient_id', v_line ->> 'final_ingredient_id'
          )
        );
      elsif v_matching_count = 1 then
        select item into v_rule
        from pg_catalog.jsonb_array_elements(v_rules) item
        where item ->> 'scope_kind' = 'SCHOOL'
          and item ->> 'target_ingredient_id'
            = v_line ->> 'final_ingredient_id';
        v_line := atlas_core.rmvp_02b_transform_line(v_line, v_rule);
      end if;
    end if;
    v_new_lines := v_new_lines || pg_catalog.jsonb_build_array(v_line);
  end loop;
  v_lines := v_new_lines;

  -- SCHOOL_DISH is the highest-authority layer.
  for v_rule in
    select item
    from pg_catalog.jsonb_array_elements(v_rules) item
    where item ->> 'scope_kind' = 'SCHOOL_DISH'
    order by item ->> 'adjustment_id'
  loop
    if v_rule ->> 'action_kind' = 'ADD' then
      v_lines := v_lines || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'selected_dish_id', target_dish_id,
          'selected_recipe_id', v_recipe_id,
          'selected_recipe_version_id', v_recipe_version_id,
          'basis_portions', v_basis_portions,
          'base_recipe_line_id', null,
          'base_recipe_line_revision_id', null,
          'adjustment_line_id', v_rule ->> 'adjustment_line_id',
          'line_code', null,
          'base_ingredient_id', null,
          'base_quantity_per_basis', null,
          'base_unit_id', null,
          'base_disposition', null,
          'final_ingredient_id', v_rule ->> 'target_ingredient_id',
          'final_quantity_per_basis',
            atlas_core.pa_05b_safe_numeric(
              v_rule ->> 'quantity_per_basis'
            ),
          'final_unit_id', v_rule ->> 'unit_id',
          'final_disposition', 'PRESENT',
          'source_layer', 'SCHOOL_DISH',
          'applied_adjustment_ids',
            pg_catalog.jsonb_build_array(v_rule ->> 'adjustment_id'),
          'applied_revision_ids',
            pg_catalog.jsonb_build_array(v_rule ->> 'revision_id'),
          'lineage',
            pg_catalog.jsonb_build_array(
              pg_catalog.jsonb_build_object(
                'adjustment_id', v_rule ->> 'adjustment_id',
                'revision_id', v_rule ->> 'revision_id',
                'revision_number',
                  atlas_core.pa_05b_safe_bigint(
                    v_rule ->> 'revision_number'
                  ),
                'scope_kind', 'SCHOOL_DISH',
                'action_kind', 'ADD',
                'before', null,
                'after', pg_catalog.jsonb_build_object(
                  'ingredient_id', v_rule ->> 'target_ingredient_id',
                  'quantity_per_basis',
                    atlas_core.pa_05b_safe_numeric(
                      v_rule ->> 'quantity_per_basis'
                    ),
                  'unit_id', v_rule ->> 'unit_id',
                  'disposition', 'PRESENT'
                ),
                'reason_code', v_rule ->> 'reason_code',
                'reason_note', v_rule ->> 'reason_note',
                'effective_from', v_rule ->> 'effective_from',
                'effective_to', v_rule ->> 'effective_to',
                'is_preview',
                  coalesce((v_rule ->> 'is_preview')::boolean, false)
              )
            )
        )
      );
    else
      v_found := false;
      v_new_lines := '[]'::jsonb;
      for v_line in
        select value from pg_catalog.jsonb_array_elements(v_lines)
      loop
        if v_line ->> 'base_recipe_line_id'
             = v_rule ->> 'target_recipe_line_id' then
          v_found := true;
          if v_line ->> 'final_disposition' = 'PRESENT' then
            v_line := atlas_core.rmvp_02b_transform_line(v_line, v_rule);
          else
            v_blockers := v_blockers || pg_catalog.jsonb_build_array(
              pg_catalog.jsonb_build_object(
                'code', 'TARGET_NOT_APPLICABLE',
                'message',
                  'A SCHOOL_DISH target RecipeLine is no longer present.',
                'adjustment_id', v_rule ->> 'adjustment_id',
                'recipe_line_id', v_rule ->> 'target_recipe_line_id'
              )
            );
          end if;
        end if;
        v_new_lines := v_new_lines || pg_catalog.jsonb_build_array(v_line);
      end loop;
      if not v_found then
        v_blockers := v_blockers || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', 'TARGET_NOT_APPLICABLE',
            'message',
              'A SCHOOL_DISH target RecipeLine is not in the selected RecipeVersion.',
            'adjustment_id', v_rule ->> 'adjustment_id',
            'recipe_line_id', v_rule ->> 'target_recipe_line_id'
          )
        );
      end if;
      v_lines := v_new_lines;
    end if;
  end loop;

  for v_duplicate in
    select
      line ->> 'final_ingredient_id' as ingredient_id,
      pg_catalog.count(*) as line_count,
      pg_catalog.jsonb_agg(
        coalesce(
          line ->> 'base_recipe_line_id',
          line ->> 'adjustment_line_id'
        )
      ) as line_ids
    from pg_catalog.jsonb_array_elements(v_lines) line
    where line ->> 'final_disposition' = 'PRESENT'
    group by line ->> 'final_ingredient_id'
    having pg_catalog.count(*) > 1
  loop
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'DUPLICATE_EFFECTIVE_INGREDIENT',
        'message',
          'The effective composition contains the same Ingredient on more than one atomic line.',
        'ingredient_id', v_duplicate.ingredient_id,
        'line_ids', v_duplicate.line_ids
      )
    );
  end loop;

  return pg_catalog.jsonb_build_object(
    'status',
      case
        when pg_catalog.jsonb_array_length(v_blockers) = 0
          then 'READY'
        else 'BLOCKED'
      end,
    'as_of_date', target_as_of_date,
    'school_id', target_school_id,
    'dish_id', target_dish_id,
    'historical', v_historical,
    'selected_recipe', pg_catalog.jsonb_build_object(
      'dish_id', target_dish_id,
      'recipe_id', v_recipe_id,
      'recipe_version_id', v_recipe_version_id,
      'selection_scope', v_recipe_scope,
      'basis_portions', v_basis_portions
    ),
    'lines', v_lines,
    'warnings', v_warnings,
    'blockers', v_blockers
  );
end;
$$;

create or replace function atlas_core.rmvp_02b_validate_proposed_adjustment(
  proposed_adjustment jsonb,
  preview_as_of_date date,
  replaced_adjustment_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_blockers jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_scope text := proposed_adjustment ->> 'scope_kind';
  v_action text := proposed_adjustment ->> 'action_kind';
  v_adjustment_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'adjustment_id'
  );
  v_revision_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'revision_id'
  );
  v_school_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'school_id'
  );
  v_dish_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'dish_id'
  );
  v_school_type_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'school_type_id'
  );
  v_target_ingredient_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'target_ingredient_id'
  );
  v_target_recipe_line_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'target_recipe_line_id'
  );
  v_adjustment_line_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'adjustment_line_id'
  );
  v_substitute_ingredient_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'substitute_ingredient_id'
  );
  v_quantity numeric := atlas_core.pa_05b_safe_numeric(
    proposed_adjustment ->> 'quantity_per_basis'
  );
  v_unit_id uuid := atlas_core.pa_05b_safe_uuid(
    proposed_adjustment ->> 'unit_id'
  );
  v_effective_from date := atlas_core.rmvp_02b_safe_date(
    proposed_adjustment ->> 'effective_from'
  );
  v_effective_to date := atlas_core.rmvp_02b_safe_date(
    proposed_adjustment ->> 'effective_to'
  );
  v_identity_valid boolean := false;
  v_cycle boolean := false;
begin
  if proposed_adjustment is null
     or pg_catalog.jsonb_typeof(proposed_adjustment) <> 'object' then
    return pg_catalog.jsonb_build_object(
      'valid', false,
      'blockers', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'PROPOSAL_REQUIRED',
          'message', 'A proposed adjustment object is required.'
        )
      ),
      'warnings', '[]'::jsonb
    );
  end if;

  if v_adjustment_id is null or v_revision_id is null then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'STABLE_IDENTITY_REQUIRED',
        'message',
          'The proposal requires stable adjustment and revision UUIDs.'
      )
    );
  end if;
  if v_scope not in (
      'SYSTEM_INGREDIENT',
      'SYSTEM_DISH',
      'SCHOOL',
      'SCHOOL_DISH'
    )
     or v_action not in (
       'ADD',
       'REPLACE',
       'ADJUST_QUANTITY',
       'REMOVE'
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'SCOPE_ACTION_INVALID',
        'message', 'The scope or action is outside the closed catalog.'
      )
    );
  else
    v_identity_valid :=
      (
        v_scope = 'SYSTEM_INGREDIENT'
        and v_action = 'REPLACE'
        and v_school_id is null
        and v_dish_id is null
        and v_school_type_id is null
        and v_target_ingredient_id is not null
        and v_target_recipe_line_id is null
        and v_adjustment_line_id is null
      )
      or (
        v_scope = 'SYSTEM_DISH'
        and v_school_id is null
        and v_dish_id is not null
        and (
          (
            v_action = 'ADD'
            and v_target_ingredient_id is not null
            and v_target_recipe_line_id is null
            and v_adjustment_line_id is not null
          )
          or (
            v_action in ('REPLACE', 'ADJUST_QUANTITY', 'REMOVE')
            and v_target_ingredient_id is null
            and v_target_recipe_line_id is not null
            and v_adjustment_line_id is null
          )
        )
      )
      or (
        v_scope = 'SCHOOL'
        and v_action in ('REPLACE', 'REMOVE')
        and v_school_id is not null
        and v_dish_id is null
        and v_school_type_id is null
        and v_target_ingredient_id is not null
        and v_target_recipe_line_id is null
        and v_adjustment_line_id is null
      )
      or (
        v_scope = 'SCHOOL_DISH'
        and v_school_id is not null
        and v_dish_id is not null
        and v_school_type_id is null
        and (
          (
            v_action = 'ADD'
            and v_target_ingredient_id is not null
            and v_target_recipe_line_id is null
            and v_adjustment_line_id is not null
          )
          or (
            v_action in ('REPLACE', 'ADJUST_QUANTITY', 'REMOVE')
            and v_target_ingredient_id is null
            and v_target_recipe_line_id is not null
            and v_adjustment_line_id is null
          )
        )
      );
    if not v_identity_valid then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'TYPED_SCOPE_INVALID',
          'message',
            'The typed School, Dish, SchoolType, Ingredient, RecipeLine, and adjustment-line fields do not match the selected scope and action.'
        )
      );
    end if;
  end if;

  if v_effective_from is null
     or (
       proposed_adjustment ? 'effective_to'
       and proposed_adjustment ->> 'effective_to' is not null
       and v_effective_to is null
     )
     or (
       v_effective_to is not null
       and v_effective_to <= v_effective_from
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'EFFECTIVE_PERIOD_INVALID',
        'message',
          'effective_from is required and effective_to must be later using a half-open interval.'
      )
    );
  elsif preview_as_of_date is not null
        and (
          preview_as_of_date < v_effective_from
          or (
            v_effective_to is not null
            and preview_as_of_date >= v_effective_to
          )
        ) then
    v_warnings := v_warnings || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'PROPOSAL_NOT_EFFECTIVE_ON_PREVIEW_DATE',
        'message',
          'The proposed rule is outside the requested preview date and therefore has no hypothetical effect.'
      )
    );
  end if;

  if pg_catalog.btrim(
       coalesce(proposed_adjustment ->> 'reason_code', '')
     ) = ''
     or pg_catalog.btrim(
       coalesce(proposed_adjustment ->> 'reason_note', '')
     ) = '' then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'REASON_REQUIRED',
        'message', 'A reason code and non-empty reason note are required.'
      )
    );
  end if;

  if v_action = 'REPLACE' then
    if v_substitute_ingredient_id is null
       or (
         v_quantity is null
         and v_unit_id is not null
       )
       or (
         v_quantity is not null
         and (v_quantity <= 0 or v_unit_id is null)
       ) then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'REPLACE_PAYLOAD_INVALID',
          'message',
            'REPLACE requires an active substitute and either no quantity override or a positive quantity with an explicit Unit.'
        )
      );
    end if;
  elsif v_action = 'ADJUST_QUANTITY' then
    if v_quantity is null or v_quantity <= 0
       or v_substitute_ingredient_id is not null
       or v_unit_id is not null then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'QUANTITY_PAYLOAD_INVALID',
          'message',
            'ADJUST_QUANTITY requires one positive replacement quantity and preserves Ingredient and Unit.'
        )
      );
    end if;
  elsif v_action = 'ADD' then
    if v_quantity is null or v_quantity <= 0
       or v_unit_id is null
       or v_substitute_ingredient_id is not null then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'ADD_PAYLOAD_INVALID',
          'message',
            'ADD requires an active Ingredient, a positive quantity, an active Unit, and a stable adjustment-line identity.'
        )
      );
    end if;
  elsif v_action = 'REMOVE' then
    if v_quantity is not null
       or v_unit_id is not null
       or v_substitute_ingredient_id is not null then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'REMOVE_PAYLOAD_INVALID',
          'message',
            'REMOVE accepts no substitute, quantity, or Unit payload.'
        )
      );
    end if;
  end if;

  if v_substitute_ingredient_id is not null
     and not exists (
       select 1
       from atlas_admin.ingredients ingredient
       where ingredient.ingredient_id = v_substitute_ingredient_id
         and ingredient.ingredient_status = 'ACTIVE'
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'SUBSTITUTE_INGREDIENT_INACTIVE',
        'message', 'The substitute Ingredient must be active.'
      )
    );
  end if;
  if v_scope in ('SYSTEM_INGREDIENT', 'SCHOOL')
     and v_target_ingredient_id is not null
     and not exists (
       select 1
       from atlas_admin.ingredients ingredient
       where ingredient.ingredient_id = v_target_ingredient_id
         and ingredient.ingredient_status = 'ACTIVE'
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'TARGET_INGREDIENT_INACTIVE',
        'message', 'The targeted Ingredient must be active.'
      )
    );
  end if;
  if v_action = 'ADD'
     and not exists (
       select 1
       from atlas_admin.ingredients ingredient
       where ingredient.ingredient_id = v_target_ingredient_id
         and ingredient.ingredient_status = 'ACTIVE'
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'ADDED_INGREDIENT_INACTIVE',
        'message', 'The added Ingredient must be active.'
      )
    );
  end if;
  if v_unit_id is not null
     and not exists (
       select 1
       from atlas_admin.units unit
       where unit.unit_id = v_unit_id
         and unit.unit_status = 'ACTIVE'
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'UNIT_INACTIVE',
        'message', 'The supplied Unit must be active.'
      )
    );
  end if;
  if v_school_id is not null
     and not exists (
       select 1
       from atlas_admin.schools school
       where school.school_id = v_school_id
         and school.school_status = 'ACTIVE'
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'SCHOOL_NOT_ACTIVE',
        'message', 'The scoped School must be active.'
      )
    );
  end if;
  if v_dish_id is not null
     and not exists (
       select 1
       from atlas_admin.dishes dish
       where dish.dish_id = v_dish_id
         and dish.dish_status = 'ACTIVE'
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'DISH_NOT_ACTIVE',
        'message', 'The scoped Dish must be active.'
      )
    );
  end if;
  if v_school_type_id is not null
     and not exists (
       select 1
       from atlas_admin.school_types school_type
       where school_type.school_type_id = v_school_type_id
         and school_type.school_type_status = 'ACTIVE'
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'SCHOOL_TYPE_NOT_ACTIVE',
        'message', 'The optional SchoolType restriction must be active.'
      )
    );
  end if;
  if v_target_recipe_line_id is not null
     and not exists (
       select 1
       from atlas_admin.recipe_lines line
       join atlas_admin.recipes recipe
         on recipe.recipe_id = line.recipe_id
       where line.recipe_line_id = v_target_recipe_line_id
         and recipe.dish_id = v_dish_id
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'RECIPE_LINE_SCOPE_MISMATCH',
        'message',
          'The stable RecipeLine does not belong to a Recipe for the scoped Dish.'
      )
    );
  end if;
  if v_scope in ('SYSTEM_INGREDIENT', 'SCHOOL')
     and v_action = 'REPLACE'
     and v_target_ingredient_id = v_substitute_ingredient_id then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'SELF_REPLACEMENT',
        'message', 'An Ingredient cannot replace itself.'
      )
    );
  end if;

  if v_identity_valid and v_effective_from is not null
     and (
       v_effective_to is null
       or v_effective_to > v_effective_from
     )
     and exists (
       select 1
       from atlas_admin.recipe_composition_adjustments root
       join atlas_admin.recipe_composition_adjustment_revisions revision
         on revision.recipe_composition_adjustment_revision_id =
           root.current_revision_id
       where root.lifecycle_status = 'ACTIVE'
         and root.recipe_composition_adjustment_id
           is distinct from replaced_adjustment_id
         and root.scope_kind = v_scope
         and root.school_id is not distinct from v_school_id
         and root.dish_id is not distinct from v_dish_id
         and root.school_type_id is not distinct from v_school_type_id
         and root.target_ingredient_id
           is not distinct from v_target_ingredient_id
         and root.target_recipe_line_id
           is not distinct from v_target_recipe_line_id
         and (
           root.action_kind <> 'ADD'
           or root.adjustment_line_id is not distinct from v_adjustment_line_id
         )
         and pg_catalog.daterange(
           revision.effective_from,
           revision.effective_to,
           '[)'
         ) && pg_catalog.daterange(
           v_effective_from,
           v_effective_to,
           '[)'
         )
     ) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'OVERLAPPING_ACTIVE_RULE',
        'message',
          'An active rule already overlaps this exact typed scope and target.'
      )
    );
  end if;

  if v_scope = 'SYSTEM_INGREDIENT'
     and v_action = 'REPLACE'
     and preview_as_of_date is not null
     and v_target_ingredient_id is not null
     and v_substitute_ingredient_id is not null then
    with recursive edges(source_id, substitute_id) as (
      select
        root.target_ingredient_id,
        revision.substitute_ingredient_id
      from atlas_admin.recipe_composition_adjustments root
      join atlas_admin.recipe_composition_adjustment_revisions revision
        on revision.recipe_composition_adjustment_revision_id =
          root.current_revision_id
      where root.lifecycle_status = 'ACTIVE'
        and root.scope_kind = 'SYSTEM_INGREDIENT'
        and root.recipe_composition_adjustment_id
          is distinct from replaced_adjustment_id
        and preview_as_of_date >= revision.effective_from
        and (
          revision.effective_to is null
          or preview_as_of_date < revision.effective_to
        )
      union all
      select v_target_ingredient_id, v_substitute_ingredient_id
    ),
    walk(origin_id, current_id, path_ids, has_cycle) as (
      select
        edge.source_id,
        edge.substitute_id,
        array[edge.source_id, edge.substitute_id],
        edge.source_id = edge.substitute_id
      from edges edge
      union all
      select
        walk.origin_id,
        edge.substitute_id,
        walk.path_ids || edge.substitute_id,
        edge.substitute_id = any(walk.path_ids)
      from walk
      join edges edge on edge.source_id = walk.current_id
      where not walk.has_cycle
    )
    select coalesce(pg_catalog.bool_or(walk.has_cycle), false)
    into v_cycle
    from walk;
    if v_cycle then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'REPLACEMENT_CYCLE',
          'message',
            'The proposal would create a system Ingredient replacement cycle.'
        )
      );
    end if;
  end if;

  return pg_catalog.jsonb_build_object(
    'valid', pg_catalog.jsonb_array_length(v_blockers) = 0,
    'blockers', v_blockers,
    'warnings', v_warnings
  );
end;
$$;

create or replace function atlas_api.get_recipe_adjustment_workbench(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_recipe_adjustment_workbench';
  v_error jsonb;
  v_context jsonb;
begin
  v_error := atlas_core.rmvp_02b_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.recipe_adjustments.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02B.v1',
    'correlation_id', request ->> 'correlation_id',
    'workbench',
      atlas_core.rmvp_02b_adjustment_workbench_payload(),
    'safe_operator_message',
      'Authorized Recipe adjustment workbench data returned.'
  );
exception when others then
  return atlas_core.rmvp_02b_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'Recipe adjustment workbench data could not be returned safely.'
  );
end;
$$;

create or replace function atlas_api.resolve_effective_recipe_composition(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'resolve_effective_recipe_composition';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_context jsonb;
  v_as_of_date date;
  v_school_id uuid;
  v_dish_id uuid;
  v_historical_version_id uuid;
  v_resolution jsonb;
begin
  v_error := atlas_core.rmvp_02b_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_as_of_date := atlas_core.rmvp_02b_safe_date(
    v_payload ->> 'as_of_date'
  );
  v_school_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'school_id'
  );
  v_dish_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');
  v_historical_version_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'historical_recipe_version_id'
  );
  if v_as_of_date is null
     or v_school_id is null
     or v_dish_id is null then
    return atlas_core.rmvp_02b_read_error(
      request,
      v_name,
      'VALIDATION_FAILED',
      'An explicit as_of_date, School, and Dish are required.',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload',
          'message',
            'Provide a valid as_of_date, school_id, and dish_id.'
        )
      )
    );
  end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.recipe_adjustments.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_resolution := atlas_core.rmvp_02b_resolve_effective_composition(
    v_as_of_date,
    v_school_id,
    v_dish_id,
    null,
    null,
    v_historical_version_id
  );
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02B.v1',
    'correlation_id', request ->> 'correlation_id',
    'resolution', v_resolution,
    'safe_operator_message',
      case
        when v_resolution ->> 'status' = 'READY'
          then 'Authoritative effective Recipe composition returned.'
        else 'Effective Recipe composition is blocked; inspect the returned evidence.'
      end,
    'warnings', coalesce(v_resolution -> 'warnings', '[]'::jsonb),
    'blockers', coalesce(v_resolution -> 'blockers', '[]'::jsonb)
  );
exception when others then
  return atlas_core.rmvp_02b_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'Effective Recipe composition could not be resolved safely.'
  );
end;
$$;

create or replace function atlas_api.preview_recipe_composition_adjustment(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'preview_recipe_composition_adjustment';
  v_payload jsonb := request -> 'payload';
  v_proposal jsonb := v_payload -> 'proposed_adjustment';
  v_error jsonb;
  v_context jsonb;
  v_as_of_date date;
  v_school_id uuid;
  v_dish_id uuid;
  v_replaced_id uuid;
  v_validation jsonb;
  v_before jsonb;
  v_after jsonb;
  v_blockers jsonb;
  v_warnings jsonb;
  v_affected_count bigint := 0;
  v_before_target_ingredient text;
begin
  v_error := atlas_core.rmvp_02b_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_as_of_date := atlas_core.rmvp_02b_safe_date(
    v_payload ->> 'as_of_date'
  );
  v_school_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'school_id'
  );
  v_dish_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');
  v_replaced_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'replaces_adjustment_id'
  );
  if v_as_of_date is null or v_dish_id is null
     or v_proposal is null
     or pg_catalog.jsonb_typeof(v_proposal) <> 'object' then
    return atlas_core.rmvp_02b_read_error(
      request,
      v_name,
      'VALIDATION_FAILED',
      'An explicit date, Dish, and proposed adjustment are required.'
    );
  end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.recipe_adjustments.write',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;

  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment(
    v_proposal,
    v_as_of_date,
    v_replaced_id
  );
  v_before := atlas_core.rmvp_02b_resolve_effective_composition(
    v_as_of_date,
    v_school_id,
    v_dish_id
  );
  v_blockers := coalesce(v_validation -> 'blockers', '[]'::jsonb);
  v_warnings := coalesce(v_validation -> 'warnings', '[]'::jsonb);

  if v_proposal ->> 'action_kind' = 'REPLACE'
     and v_proposal ->> 'target_recipe_line_id' is not null then
    select line ->> 'final_ingredient_id'
    into v_before_target_ingredient
    from pg_catalog.jsonb_array_elements(v_before -> 'lines') line
    where line ->> 'base_recipe_line_id'
      = v_proposal ->> 'target_recipe_line_id';
    if v_before_target_ingredient is not null
       and v_before_target_ingredient
         = v_proposal ->> 'substitute_ingredient_id' then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'SELF_REPLACEMENT',
          'message',
            'The selected RecipeLine already resolves to the substitute Ingredient.'
        )
      );
    end if;
  end if;

  if pg_catalog.jsonb_array_length(v_blockers) = 0 then
    v_after := atlas_core.rmvp_02b_resolve_effective_composition(
      v_as_of_date,
      v_school_id,
      v_dish_id,
      v_proposal,
      v_replaced_id
    );
    v_blockers := v_blockers
      || coalesce(v_after -> 'blockers', '[]'::jsonb);
    v_warnings := v_warnings
      || coalesce(v_after -> 'warnings', '[]'::jsonb);
  else
    v_after := v_before;
  end if;

  with before_lines as (
    select
      coalesce(
        line ->> 'base_recipe_line_id',
        line ->> 'adjustment_line_id'
      ) as line_identity,
      line
    from pg_catalog.jsonb_array_elements(v_before -> 'lines') line
  ),
  after_lines as (
    select
      coalesce(
        line ->> 'base_recipe_line_id',
        line ->> 'adjustment_line_id'
      ) as line_identity,
      line
    from pg_catalog.jsonb_array_elements(v_after -> 'lines') line
  )
  select pg_catalog.count(*)
  into v_affected_count
  from before_lines
  full join after_lines using (line_identity)
  where before_lines.line is distinct from after_lines.line;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02B.v1',
    'correlation_id', request ->> 'correlation_id',
    'preview', pg_catalog.jsonb_build_object(
      'as_of_date', v_as_of_date,
      'school_id', v_school_id,
      'dish_id', v_dish_id,
      'proposed_adjustment', v_proposal,
      'before', v_before,
      'after', v_after,
      'affected_line_count', v_affected_count,
      'can_save', pg_catalog.jsonb_array_length(v_blockers) = 0,
      'warnings', v_warnings,
      'blockers', v_blockers
    ),
    'safe_operator_message',
      case
        when pg_catalog.jsonb_array_length(v_blockers) = 0
          then 'Authoritative what-if preview completed without writing.'
        else 'The proposal is blocked; no write occurred.'
      end,
    'warnings', v_warnings,
    'blockers', v_blockers
  );
exception when others then
  return atlas_core.rmvp_02b_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'The what-if preview could not be completed safely.'
  );
end;
$$;

create or replace function atlas_core.rmvp_02b_finish_success(
  request jsonb,
  actor_id uuid,
  command_receipt_id uuid,
  event_type text,
  adjustment_id uuid,
  version_before bigint,
  version_after bigint,
  before_summary jsonb,
  after_summary jsonb,
  safe_operator_message text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_events jsonb;
  v_response jsonb;
begin
  v_events := atlas_core.rmvp_01_record_change(
    request,
    actor_id,
    command_receipt_id,
    event_type,
    'RecipeCompositionAdjustment',
    adjustment_id,
    version_before,
    version_after,
    before_summary,
    after_summary
  );
  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02B.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'recipe_composition_adjustment_id', adjustment_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'aggregate_version', version_after
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'audit_event_id'
    ),
    'authoritative_readback',
      atlas_core.rmvp_02b_adjustment_workbench_payload(),
    'safe_operator_message', safe_operator_message,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(
    command_receipt_id,
    v_response,
    true
  );
end;
$$;

create or replace function atlas_api.create_recipe_composition_adjustment(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_recipe_composition_adjustment';
  v_payload jsonb := request -> 'payload';
  v_proposal jsonb;
  v_adjustment_id uuid;
  v_revision_id uuid;
  v_as_of_date date;
  v_preview_school_id uuid;
  v_preview_dish_id uuid;
  v_validation jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_after jsonb;
  v_before_target_ingredient text;
  v_scope text;
  v_action text;
  v_school_id uuid;
  v_dish_id uuid;
  v_school_type_id uuid;
  v_target_ingredient_id uuid;
  v_target_recipe_line_id uuid;
  v_adjustment_line_id uuid;
  v_substitute_ingredient_id uuid;
  v_quantity numeric;
  v_unit_id uuid;
  v_effective_from date;
  v_effective_to date;
begin
  if atlas_core.rmvp_02b_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02b_validate_command_request(request, v_name);
  end if;
  if atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) <> 1 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Creating a Recipe adjustment requires expected_version 1.',
      'ADMIN',
      v_name
    );
  end if;

  v_proposal := v_payload || pg_catalog.jsonb_build_object(
    'reason_code', request ->> 'reason_code',
    'reason_note', request ->> 'reason_note',
    'revision_number', 1,
    'source_evidence',
      coalesce(v_payload -> 'source_evidence', '{}'::jsonb)
  );
  v_adjustment_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'adjustment_id'
  );
  v_revision_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'revision_id'
  );
  v_as_of_date := atlas_core.rmvp_02b_safe_date(
    v_payload ->> 'as_of_date'
  );
  v_preview_school_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_school_id'
  );
  v_preview_dish_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_dish_id'
  );
  v_scope := v_proposal ->> 'scope_kind';
  v_action := v_proposal ->> 'action_kind';
  v_school_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'school_id'
  );
  v_dish_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'dish_id'
  );
  v_school_type_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'school_type_id'
  );
  v_target_ingredient_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'target_ingredient_id'
  );
  v_target_recipe_line_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'target_recipe_line_id'
  );
  v_adjustment_line_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'adjustment_line_id'
  );
  v_substitute_ingredient_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'substitute_ingredient_id'
  );
  v_quantity := atlas_core.pa_05b_safe_numeric(
    v_proposal ->> 'quantity_per_basis'
  );
  v_unit_id := atlas_core.pa_05b_safe_uuid(
    v_proposal ->> 'unit_id'
  );
  v_effective_from := atlas_core.rmvp_02b_safe_date(
    v_proposal ->> 'effective_from'
  );
  v_effective_to := atlas_core.rmvp_02b_safe_date(
    v_proposal ->> 'effective_to'
  );
  if v_as_of_date is null
     or v_preview_school_id is null
     or v_preview_dish_id is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The command must name the explicit date, School, and Dish used for preview.',
      'ADMIN',
      v_name
    );
  end if;

  v_prepare := atlas_core.rmvp_02b_prepare_command(
    request,
    v_name,
    'master_data.recipe_adjustments.write',
    'recipe-adjustment:' || v_adjustment_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment(
    v_proposal,
    v_as_of_date
  );
  if not coalesce((v_validation ->> 'valid')::boolean, false) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The proposed Recipe adjustment is invalid.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        coalesce(v_validation -> 'blockers', '[]'::jsonb)
      ),
      false
    );
  end if;

  if exists (
    select 1
    from atlas_admin.recipe_composition_adjustments root
    where root.recipe_composition_adjustment_id = v_adjustment_id
  ) or exists (
    select 1
    from atlas_admin.recipe_composition_adjustment_revisions revision
    where revision.recipe_composition_adjustment_revision_id = v_revision_id
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'The stable adjustment or revision identity is already in use.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      pg_catalog.concat_ws(
        '|',
        v_scope,
        v_school_id::text,
        v_dish_id::text,
        v_school_type_id::text,
        v_target_ingredient_id::text,
        v_target_recipe_line_id::text,
        v_adjustment_line_id::text
      ),
      0
    )
  );
  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment(
    v_proposal,
    v_as_of_date
  );
  if not coalesce((v_validation ->> 'valid')::boolean, false) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'The adjustment scope changed after preview. Review and retry.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        coalesce(v_validation -> 'blockers', '[]'::jsonb)
      ),
      false
    );
  end if;

  v_after := atlas_core.rmvp_02b_resolve_effective_composition(
    v_as_of_date,
    v_preview_school_id,
    v_preview_dish_id,
    v_proposal
  );
  if v_action = 'REPLACE'
     and v_target_recipe_line_id is not null then
    select line ->> 'final_ingredient_id'
    into v_before_target_ingredient
    from pg_catalog.jsonb_array_elements(
      (
        atlas_core.rmvp_02b_resolve_effective_composition(
          v_as_of_date,
          v_preview_school_id,
          v_preview_dish_id
        )
      ) -> 'lines'
    ) line
    where line ->> 'base_recipe_line_id' = v_target_recipe_line_id::text;
    if v_before_target_ingredient = v_substitute_ingredient_id::text then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'VALIDATION_FAILED',
          'The selected RecipeLine already resolves to the substitute Ingredient.',
          'ADMIN',
          v_name
        ),
        false
      );
    end if;
  end if;
  if v_after ->> 'status' <> 'READY' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'The proposed rule does not produce a valid effective composition.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        coalesce(v_after -> 'blockers', '[]'::jsonb)
      ),
      false
    );
  end if;

  insert into atlas_admin.recipe_composition_adjustments (
    recipe_composition_adjustment_id,
    scope_kind,
    action_kind,
    school_id,
    dish_id,
    school_type_id,
    target_ingredient_id,
    target_recipe_line_id,
    adjustment_line_id,
    created_by_actor_id,
    updated_by_actor_id
  ) values (
    v_adjustment_id,
    v_scope,
    v_action,
    v_school_id,
    v_dish_id,
    v_school_type_id,
    v_target_ingredient_id,
    v_target_recipe_line_id,
    v_adjustment_line_id,
    v_actor_id,
    v_actor_id
  );
  insert into atlas_admin.recipe_composition_adjustment_revisions (
    recipe_composition_adjustment_revision_id,
    recipe_composition_adjustment_id,
    scope_kind,
    action_kind,
    revision_number,
    revision_status,
    effective_from,
    effective_to,
    substitute_ingredient_id,
    quantity_per_basis,
    unit_id,
    reason_code,
    reason_note,
    source_evidence,
    created_by_actor_id
  ) values (
    v_revision_id,
    v_adjustment_id,
    v_scope,
    v_action,
    1,
    'ACTIVE',
    v_effective_from,
    v_effective_to,
    v_substitute_ingredient_id,
    v_quantity,
    v_unit_id,
    request ->> 'reason_code',
    request ->> 'reason_note',
    coalesce(v_payload -> 'source_evidence', '{}'::jsonb),
    v_actor_id
  );
  update atlas_admin.recipe_composition_adjustments
  set current_revision_id = v_revision_id,
      current_revision_number = 1,
      updated_at = pg_catalog.transaction_timestamp()
  where recipe_composition_adjustment_id = v_adjustment_id;

  return atlas_core.rmvp_02b_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeCompositionAdjustmentCreated',
    v_adjustment_id,
    null,
    1,
    null,
    pg_catalog.jsonb_build_object(
      'scope_kind', v_scope,
      'action_kind', v_action,
      'revision_id', v_revision_id,
      'effective_from', v_effective_from,
      'effective_to', v_effective_to
    ),
    'Recipe composition adjustment created after authoritative preview.'
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The adjustment target changed concurrently. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when unique_violation or exclusion_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The adjustment identity, predecessor, or target conflicts with existing history.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Recipe composition adjustment could not be created safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.supersede_recipe_composition_adjustment(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'supersede_recipe_composition_adjustment';
  v_payload jsonb := request -> 'payload';
  v_adjustment_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'adjustment_id'
  );
  v_revision_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'revision_id'
  );
  v_predecessor_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'predecessor_revision_id'
  );
  v_as_of_date date := atlas_core.rmvp_02b_safe_date(
    v_payload ->> 'as_of_date'
  );
  v_preview_school_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_school_id'
  );
  v_preview_dish_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_dish_id'
  );
  v_root atlas_admin.recipe_composition_adjustments%rowtype;
  v_current atlas_admin.recipe_composition_adjustment_revisions%rowtype;
  v_proposal jsonb;
  v_validation jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_after jsonb;
  v_next_number integer;
  v_effective_from date;
  v_effective_to date;
  v_substitute_id uuid;
  v_quantity numeric;
  v_unit_id uuid;
  v_before_target_ingredient text;
begin
  if atlas_core.rmvp_02b_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02b_validate_command_request(request, v_name);
  end if;
  if v_adjustment_id is null or v_revision_id is null
     or v_predecessor_id is null or v_as_of_date is null
     or v_preview_school_id is null or v_preview_dish_id is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Adjustment, predecessor, successor revision, and preview date are required.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02b_prepare_command(
    request,
    v_name,
    'master_data.recipe_adjustments.write',
    'recipe-adjustment:' || v_adjustment_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select * into v_root
  from atlas_admin.recipe_composition_adjustments
  where recipe_composition_adjustment_id = v_adjustment_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The adjustment was not found.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_root.version <> atlas_core.pa_05b_safe_bigint(
       request ->> 'expected_version'
     ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The adjustment changed after it was loaded.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_root.version
      ),
      false
    );
  end if;
  if v_root.lifecycle_status <> 'ACTIVE'
     or v_root.current_revision_id <> v_predecessor_id then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'Only the exact current ACTIVE revision can be superseded.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select * into strict v_current
  from atlas_admin.recipe_composition_adjustment_revisions
  where recipe_composition_adjustment_revision_id =
    v_root.current_revision_id;
  v_effective_from := atlas_core.rmvp_02b_safe_date(
    v_payload ->> 'effective_from'
  );
  v_effective_to := atlas_core.rmvp_02b_safe_date(
    v_payload ->> 'effective_to'
  );
  if v_effective_from < v_current.effective_from then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'A successor cannot begin before its direct predecessor.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  v_next_number := v_root.current_revision_number + 1;
  v_proposal := v_payload || pg_catalog.jsonb_build_object(
    'adjustment_id', v_root.recipe_composition_adjustment_id,
    'revision_id', v_revision_id,
    'revision_number', v_next_number,
    'scope_kind', v_root.scope_kind,
    'action_kind', v_root.action_kind,
    'school_id', v_root.school_id,
    'dish_id', v_root.dish_id,
    'school_type_id', v_root.school_type_id,
    'target_ingredient_id', v_root.target_ingredient_id,
    'target_recipe_line_id', v_root.target_recipe_line_id,
    'adjustment_line_id', v_root.adjustment_line_id,
    'reason_code', request ->> 'reason_code',
    'reason_note', request ->> 'reason_note',
    'source_evidence',
      coalesce(v_payload -> 'source_evidence', '{}'::jsonb)
  );
  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment(
    v_proposal,
    v_as_of_date,
    v_adjustment_id
  );
  if not coalesce((v_validation ->> 'valid')::boolean, false) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The successor revision is invalid.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        coalesce(v_validation -> 'blockers', '[]'::jsonb)
      ),
      false
    );
  end if;
  v_after := atlas_core.rmvp_02b_resolve_effective_composition(
    v_as_of_date,
    v_preview_school_id,
    v_preview_dish_id,
    v_proposal,
    v_adjustment_id
  );
  if v_root.action_kind = 'REPLACE'
     and v_root.target_recipe_line_id is not null then
    select line ->> 'final_ingredient_id'
    into v_before_target_ingredient
    from pg_catalog.jsonb_array_elements(
      (
        atlas_core.rmvp_02b_resolve_effective_composition(
          v_as_of_date,
          v_preview_school_id,
          v_preview_dish_id,
          null,
          v_adjustment_id
        )
      ) -> 'lines'
    ) line
    where line ->> 'base_recipe_line_id'
      = v_root.target_recipe_line_id::text;
    if v_before_target_ingredient
       = v_proposal ->> 'substitute_ingredient_id' then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'VALIDATION_FAILED',
          'The selected RecipeLine already resolves to the substitute Ingredient.',
          'ADMIN',
          v_name
        ),
        false
      );
    end if;
  end if;
  if v_after ->> 'status' <> 'READY' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'The successor does not produce a valid effective composition.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        coalesce(v_after -> 'blockers', '[]'::jsonb)
      ),
      false
    );
  end if;
  v_substitute_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'substitute_ingredient_id'
  );
  v_quantity := atlas_core.pa_05b_safe_numeric(
    v_payload ->> 'quantity_per_basis'
  );
  v_unit_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'unit_id');

  insert into atlas_admin.recipe_composition_adjustment_revisions (
    recipe_composition_adjustment_revision_id,
    recipe_composition_adjustment_id,
    scope_kind,
    action_kind,
    revision_number,
    predecessor_revision_id,
    revision_status,
    effective_from,
    effective_to,
    substitute_ingredient_id,
    quantity_per_basis,
    unit_id,
    reason_code,
    reason_note,
    source_evidence,
    created_by_actor_id
  ) values (
    v_revision_id,
    v_adjustment_id,
    v_root.scope_kind,
    v_root.action_kind,
    v_next_number,
    v_predecessor_id,
    'ACTIVE',
    v_effective_from,
    v_effective_to,
    v_substitute_id,
    v_quantity,
    v_unit_id,
    request ->> 'reason_code',
    request ->> 'reason_note',
    coalesce(v_payload -> 'source_evidence', '{}'::jsonb),
    v_actor_id
  );
  update atlas_admin.recipe_composition_adjustments
  set current_revision_id = v_revision_id,
      current_revision_number = v_next_number,
      lifecycle_status = 'ACTIVE',
      version = version + 1,
      updated_by_actor_id = v_actor_id,
      updated_at = pg_catalog.transaction_timestamp()
  where recipe_composition_adjustment_id = v_adjustment_id;

  return atlas_core.rmvp_02b_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeCompositionAdjustmentSuperseded',
    v_adjustment_id,
    v_root.version,
    v_root.version + 1,
    pg_catalog.jsonb_build_object(
      'revision_id', v_predecessor_id,
      'revision_number', v_root.current_revision_number
    ),
    pg_catalog.jsonb_build_object(
      'revision_id', v_revision_id,
      'revision_number', v_next_number,
      'effective_from', v_effective_from,
      'effective_to', v_effective_to
    ),
    'Recipe composition adjustment superseded through one direct successor.'
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The successor revision would branch or reuse an existing identity.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Recipe composition adjustment could not be superseded safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.cancel_recipe_composition_adjustment(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'cancel_recipe_composition_adjustment';
  v_payload jsonb := request -> 'payload';
  v_adjustment_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'adjustment_id'
  );
  v_revision_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'revision_id'
  );
  v_predecessor_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'predecessor_revision_id'
  );
  v_root atlas_admin.recipe_composition_adjustments%rowtype;
  v_current atlas_admin.recipe_composition_adjustment_revisions%rowtype;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_next_number integer;
  v_cancel_from date := atlas_core.rmvp_02b_safe_date(
    v_payload ->> 'effective_from'
  );
begin
  if atlas_core.rmvp_02b_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02b_validate_command_request(request, v_name);
  end if;
  if v_adjustment_id is null or v_revision_id is null
     or v_predecessor_id is null or v_cancel_from is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Adjustment, predecessor, cancellation revision, and cancellation date are required.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02b_prepare_command(
    request,
    v_name,
    'master_data.recipe_adjustments.cancel',
    'recipe-adjustment:' || v_adjustment_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_root
  from atlas_admin.recipe_composition_adjustments
  where recipe_composition_adjustment_id = v_adjustment_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The adjustment was not found.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_root.version <> atlas_core.pa_05b_safe_bigint(
       request ->> 'expected_version'
     ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The adjustment changed after it was loaded.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_root.version
      ),
      false
    );
  end if;
  if v_root.lifecycle_status <> 'ACTIVE'
     or v_root.current_revision_id <> v_predecessor_id then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'Only the exact current ACTIVE revision can be cancelled.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select * into strict v_current
  from atlas_admin.recipe_composition_adjustment_revisions
  where recipe_composition_adjustment_revision_id =
    v_root.current_revision_id;
  if v_cancel_from < v_current.effective_from
     or (
       v_current.effective_to is not null
       and v_cancel_from >= v_current.effective_to
     ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The cancellation date must fall inside the current effective period.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  v_next_number := v_root.current_revision_number + 1;
  insert into atlas_admin.recipe_composition_adjustment_revisions (
    recipe_composition_adjustment_revision_id,
    recipe_composition_adjustment_id,
    scope_kind,
    action_kind,
    revision_number,
    predecessor_revision_id,
    revision_status,
    effective_from,
    effective_to,
    reason_code,
    reason_note,
    source_evidence,
    created_by_actor_id
  ) values (
    v_revision_id,
    v_adjustment_id,
    v_root.scope_kind,
    v_root.action_kind,
    v_next_number,
    v_predecessor_id,
    'CANCELLED',
    v_cancel_from,
    null,
    request ->> 'reason_code',
    request ->> 'reason_note',
    pg_catalog.jsonb_build_object(
      'cancellation_of_revision_id', v_predecessor_id
    ),
    v_actor_id
  );
  update atlas_admin.recipe_composition_adjustments
  set current_revision_id = v_revision_id,
      current_revision_number = v_next_number,
      lifecycle_status = 'CANCELLED',
      version = version + 1,
      updated_by_actor_id = v_actor_id,
      updated_at = pg_catalog.transaction_timestamp()
  where recipe_composition_adjustment_id = v_adjustment_id;

  return atlas_core.rmvp_02b_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeCompositionAdjustmentCancelled',
    v_adjustment_id,
    v_root.version,
    v_root.version + 1,
    pg_catalog.jsonb_build_object(
      'revision_id', v_predecessor_id,
      'lifecycle_status', 'ACTIVE'
    ),
    pg_catalog.jsonb_build_object(
      'revision_id', v_revision_id,
      'lifecycle_status', 'CANCELLED'
    ),
    'Recipe composition adjustment cancelled without deleting history.'
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The cancellation would branch or reuse an existing identity.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Recipe composition adjustment could not be cancelled safely.',
      'ADMIN',
      v_name
  );
end;
$$;

create or replace function atlas_legacy.import_recipe_adjustment_snapshot(
  snapshot jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_source_system text := pg_catalog.btrim(
    coalesce(snapshot ->> 'source_system', '')
  );
  v_snapshot_id text := pg_catalog.btrim(
    coalesce(snapshot ->> 'snapshot_id', '')
  );
  v_checksum text := pg_catalog.lower(
    pg_catalog.btrim(coalesce(snapshot ->> 'snapshot_checksum', ''))
  );
  v_calculated_checksum text;
  v_exported_at timestamptz := atlas_core.pa_05b_safe_timestamptz(
    snapshot ->> 'exported_at'
  );
  v_imported_by_actor_id uuid := atlas_core.pa_05b_safe_uuid(
    snapshot ->> 'imported_by_actor_id'
  );
  v_records jsonb := snapshot -> 'records';
  v_existing atlas_legacy.import_batches%rowtype;
  v_batch_id uuid := gen_random_uuid();
  v_prepared jsonb := '[]'::jsonb;
  v_errors jsonb := '[]'::jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_ambiguities jsonb := '[]'::jsonb;
  v_cycles jsonb := '[]'::jsonb;
  v_source_counts jsonb := '{}'::jsonb;
  v_total bigint := 0;
  v_inserted bigint := 0;
  v_skipped bigint := 0;
  v_updated bigint := 0;
  v_array record;
  v_item record;
  v_row jsonb;
  v_scope text;
  v_action text;
  v_layer text;
  v_legacy_id text;
  v_adjustment_id uuid;
  v_revision_id uuid;
  v_cancellation_revision_id uuid;
  v_school_id uuid;
  v_dish_id uuid;
  v_school_type_id uuid;
  v_target_ingredient_id uuid;
  v_legacy_target_ingredient_id uuid;
  v_target_recipe_line_id uuid;
  v_adjustment_line_id uuid;
  v_substitute_id uuid;
  v_unit_id uuid;
  v_effective_from date;
  v_effective_to date;
  v_quantity numeric;
  v_is_active boolean;
  v_line_count bigint;
  v_validation jsonb;
  v_result jsonb;
  v_cycle_found boolean := false;
begin
  if current_user <> 'postgres' then
    raise exception using
      errcode = '42501',
      message =
        'RMVP-02B import is restricted to the privileged local database operator.';
  end if;
  if snapshot is null or pg_catalog.jsonb_typeof(snapshot) <> 'object' then
    return pg_catalog.jsonb_build_object(
      'status', 'REJECTED',
      'validation_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'SNAPSHOT_REQUIRED',
          'message', 'A JSON snapshot object is required.'
        )
      )
    );
  end if;
  v_calculated_checksum := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(
        (snapshot - 'snapshot_checksum')::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
  if v_source_system <> 'OPS_V1_RECIPE_ADJUSTMENTS'
     or v_snapshot_id = ''
     or v_checksum !~ '^[0-9a-f]{64}$'
     or v_checksum <> v_calculated_checksum
     or v_exported_at is null
     or v_imported_by_actor_id is null
     or not exists (
       select 1
       from atlas_core.actors actor
       where actor.actor_id = v_imported_by_actor_id
         and actor.actor_status = 'ACTIVE'
     )
     or v_records is null
     or pg_catalog.jsonb_typeof(v_records) <> 'object'
     or (
       select array_agg(key order by key)::text[]
       from pg_catalog.jsonb_object_keys(v_records) key
     ) is distinct from array[
       'ingredient_change_orders',
       'school_dish_overrides',
       'school_overrides',
       'system_bom_change_orders'
     ]::text[]
     or exists (
       select 1
       from pg_catalog.jsonb_each(v_records) item
       where pg_catalog.jsonb_typeof(item.value) <> 'array'
     ) then
    return pg_catalog.jsonb_build_object(
      'status', 'REJECTED',
      'validation_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'SNAPSHOT_ENVELOPE_INVALID',
          'message',
            'The source, snapshot identity, canonical checksum, export time, active import actor, or exact four-array records object is invalid.'
        )
      )
    );
  end if;

  select * into v_existing
  from atlas_legacy.import_batches batch
  where batch.source_system = v_source_system
    and batch.snapshot_id = v_snapshot_id;
  if found then
    if v_existing.snapshot_checksum <> v_checksum then
      return pg_catalog.jsonb_build_object(
        'status', 'REJECTED',
        'validation_errors', pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', 'SNAPSHOT_ID_REUSED',
            'message',
              'The snapshot identity was already used with different content.'
          )
        )
      );
    end if;
    return coalesce(
      v_existing.result_payload,
      pg_catalog.jsonb_build_object(
        'status', 'REPLAYED',
        'import_batch_id', v_existing.import_batch_id,
        'operation_counts', pg_catalog.jsonb_build_object(
          'inserted', 0,
          'updated', 0,
          'skipped',
            coalesce(
              atlas_core.pa_05b_safe_bigint(
                v_existing.source_counts ->> 'total'
              ),
              0
            ),
          'rejected', 0
        )
      )
    ) || pg_catalog.jsonb_build_object('status', 'REPLAYED');
  end if;

  for v_array in
    select key, value
    from pg_catalog.jsonb_each(v_records)
  loop
    if v_array.key not in (
      'ingredient_change_orders',
      'system_bom_change_orders',
      'school_overrides',
      'school_dish_overrides'
    ) or pg_catalog.jsonb_typeof(v_array.value) <> 'array' then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'LEGACY_ARRAY_INVALID',
          'array', v_array.key,
          'message',
            'Only the four explicit OPS v1 adjustment arrays are accepted.'
        )
      );
      continue;
    end if;
    v_source_counts := v_source_counts
      || pg_catalog.jsonb_build_object(
        v_array.key,
        pg_catalog.jsonb_array_length(v_array.value)
      );
    for v_item in
      select value, ordinality
      from pg_catalog.jsonb_array_elements(v_array.value)
        with ordinality
    loop
      v_total := v_total + 1;
      v_row := v_item.value;
      v_legacy_id := pg_catalog.btrim(coalesce(v_row ->> 'legacy_id', ''));
      v_scope := case v_array.key
        when 'ingredient_change_orders' then 'SYSTEM_INGREDIENT'
        when 'system_bom_change_orders' then 'SYSTEM_DISH'
        when 'school_overrides' then 'SCHOOL'
        when 'school_dish_overrides' then 'SCHOOL_DISH'
      end;
      v_layer := case v_array.key
        when 'ingredient_change_orders'
          then 'OPS_V1_INGREDIENT_CHANGE_ORDER'
        when 'system_bom_change_orders'
          then 'OPS_V1_SYSTEM_BOM_CHANGE_ORDER'
        when 'school_overrides'
          then 'OPS_V1_SCHOOL_OVERRIDE'
        when 'school_dish_overrides'
          then 'OPS_V1_SCHOOL_DISH_OVERRIDE'
      end;
      v_action := pg_catalog.upper(
        pg_catalog.btrim(
          coalesce(
            v_row ->> 'action',
            case
              when v_scope = 'SYSTEM_INGREDIENT' then 'REPLACE'
              else ''
            end
          )
        )
      );
      v_adjustment_id := (
        pg_catalog.md5(v_layer || ':' || v_legacy_id)
      )::uuid;
      v_revision_id := (
        pg_catalog.md5(v_layer || ':' || v_legacy_id || ':revision:1')
      )::uuid;
      v_cancellation_revision_id := (
        pg_catalog.md5(v_layer || ':' || v_legacy_id || ':revision:2')
      )::uuid;
      v_school_id := coalesce(
        atlas_core.pa_05b_safe_uuid(v_row ->> 'school_id'),
        (
          select mapping.school_id
          from atlas_legacy.master_data_mappings mapping
          where mapping.object_type = 'SCHOOL'
            and mapping.legacy_id = v_row ->> 'school_legacy_id'
          order by mapping.updated_at desc
          limit 1
        )
      );
      v_dish_id := coalesce(
        atlas_core.pa_05b_safe_uuid(v_row ->> 'dish_id'),
        (
          select mapping.dish_id
          from atlas_legacy.master_data_mappings mapping
          where mapping.object_type = 'DISH'
            and mapping.legacy_id = v_row ->> 'dish_legacy_id'
          order by mapping.updated_at desc
          limit 1
        )
      );
      v_school_type_id := coalesce(
        atlas_core.pa_05b_safe_uuid(v_row ->> 'school_type_id'),
        (
          select mapping.school_type_id
          from atlas_legacy.master_data_mappings mapping
          where mapping.object_type = 'SCHOOL_TYPE'
            and mapping.legacy_id = v_row ->> 'school_type_legacy_id'
          order by mapping.updated_at desc
          limit 1
        )
      );
      v_target_ingredient_id := coalesce(
        atlas_core.pa_05b_safe_uuid(v_row ->> 'target_ingredient_id'),
        (
          select mapping.ingredient_id
          from atlas_legacy.master_data_mappings mapping
          where mapping.object_type = 'INGREDIENT'
            and mapping.legacy_id =
              v_row ->> 'target_ingredient_legacy_id'
          order by mapping.updated_at desc
          limit 1
        )
      );
      v_legacy_target_ingredient_id := v_target_ingredient_id;
      v_target_recipe_line_id := coalesce(
        atlas_core.pa_05b_safe_uuid(v_row ->> 'target_recipe_line_id'),
        (
          select mapping.recipe_line_id
          from atlas_legacy.master_data_mappings mapping
          where mapping.object_type = 'RECIPE_LINE'
            and mapping.legacy_id =
              v_row ->> 'target_recipe_line_legacy_id'
          order by mapping.updated_at desc
          limit 1
        )
      );
      v_substitute_id := coalesce(
        atlas_core.pa_05b_safe_uuid(
          v_row ->> 'substitute_ingredient_id'
        ),
        (
          select mapping.ingredient_id
          from atlas_legacy.master_data_mappings mapping
          where mapping.object_type = 'INGREDIENT'
            and mapping.legacy_id =
              v_row ->> 'substitute_ingredient_legacy_id'
          order by mapping.updated_at desc
          limit 1
        )
      );
      v_unit_id := coalesce(
        atlas_core.pa_05b_safe_uuid(v_row ->> 'unit_id'),
        (
          select mapping.unit_id
          from atlas_legacy.master_data_mappings mapping
          where mapping.object_type = 'UNIT'
            and mapping.legacy_id = v_row ->> 'unit_legacy_id'
          order by mapping.updated_at desc
          limit 1
        )
      );
      v_effective_from := atlas_core.rmvp_02b_safe_date(
        v_row ->> 'effective_from'
      );
      v_effective_to := atlas_core.rmvp_02b_safe_date(
        v_row ->> 'effective_to'
      );
      v_quantity := atlas_core.pa_05b_safe_numeric(
        v_row ->> 'quantity_per_basis'
      );
      begin
        v_is_active := coalesce((v_row ->> 'is_active')::boolean, true);
      exception when others then
        v_is_active := null;
      end;

      if v_legacy_id = '' or pg_catalog.jsonb_typeof(v_row) <> 'object'
         or v_is_active is null then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', 'LEGACY_RECORD_INVALID',
            'array', v_array.key,
            'row_number', v_item.ordinality,
            'legacy_id', nullif(v_legacy_id, ''),
            'message',
              'Every legacy record requires a stable legacy_id, object shape, and boolean is_active.'
          )
        );
        continue;
      end if;

      if v_action <> 'ADD'
         and v_scope in ('SYSTEM_DISH', 'SCHOOL_DISH')
         and v_target_recipe_line_id is null
         and v_legacy_target_ingredient_id is not null
         and v_dish_id is not null then
        if v_scope = 'SCHOOL_DISH' and v_school_id is not null then
          select school.school_type_id
          into v_school_type_id
          from atlas_admin.schools school
          where school.school_id = v_school_id;
        end if;
        select pg_catalog.count(distinct revision.recipe_line_id)
        into v_line_count
        from atlas_admin.recipes recipe
        join atlas_admin.recipe_versions version
          on version.recipe_id = recipe.recipe_id
         and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
        join atlas_admin.recipe_line_revisions revision
          on revision.recipe_version_id = version.recipe_version_id
         and revision.line_disposition = 'PRESENT'
        where recipe.dish_id = v_dish_id
          and recipe.recipe_status = 'ACTIVE'
          and revision.ingredient_id = v_legacy_target_ingredient_id
          and (
            (
              v_school_type_id is not null
              and recipe.school_type_id = v_school_type_id
            )
            or (
              not exists (
                select 1
                from atlas_admin.recipes typed_recipe
                join atlas_admin.recipe_versions typed_version
                  on typed_version.recipe_id = typed_recipe.recipe_id
                 and typed_version.recipe_version_status =
                   'RELEASED_FOR_PLANNING'
                where typed_recipe.dish_id = v_dish_id
                  and typed_recipe.school_type_id = v_school_type_id
                  and typed_recipe.recipe_status = 'ACTIVE'
              )
              and recipe.school_type_id is null
            )
          );
        if v_line_count = 1 then
          select revision.recipe_line_id
          into v_target_recipe_line_id
          from atlas_admin.recipes recipe
          join atlas_admin.recipe_versions version
            on version.recipe_id = recipe.recipe_id
           and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
          join atlas_admin.recipe_line_revisions revision
            on revision.recipe_version_id = version.recipe_version_id
           and revision.line_disposition = 'PRESENT'
          where recipe.dish_id = v_dish_id
            and recipe.recipe_status = 'ACTIVE'
            and revision.ingredient_id = v_legacy_target_ingredient_id
            and (
              (
                v_school_type_id is not null
                and recipe.school_type_id = v_school_type_id
              )
              or (
                not exists (
                  select 1
                  from atlas_admin.recipes typed_recipe
                  join atlas_admin.recipe_versions typed_version
                    on typed_version.recipe_id = typed_recipe.recipe_id
                   and typed_version.recipe_version_status =
                     'RELEASED_FOR_PLANNING'
                  where typed_recipe.dish_id = v_dish_id
                    and typed_recipe.school_type_id = v_school_type_id
                    and typed_recipe.recipe_status = 'ACTIVE'
                )
                and recipe.school_type_id is null
              )
            );
        elsif v_line_count = 0 then
          v_missing := v_missing || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'array', v_array.key,
              'legacy_id', v_legacy_id,
              'reference', 'RECIPE_LINE',
              'message',
                'No exact released RecipeLine matches the legacy Ingredient target.'
            )
          );
        else
          v_ambiguities := v_ambiguities || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'array', v_array.key,
              'legacy_id', v_legacy_id,
              'reference', 'RECIPE_LINE',
              'candidate_count', v_line_count,
              'message',
                'The legacy Ingredient target matches more than one stable RecipeLine.'
            )
          );
        end if;
        v_target_ingredient_id := null;
      end if;
      if v_action = 'ADD' then
        v_adjustment_line_id := (
          pg_catalog.md5(
            v_layer || ':' || v_legacy_id || ':adjustment-line'
          )
        )::uuid;
      else
        v_adjustment_line_id := null;
      end if;

      v_row := pg_catalog.jsonb_build_object(
        'adjustment_id', v_adjustment_id,
        'revision_id', v_revision_id,
        'revision_number', 1,
        'scope_kind', v_scope,
        'action_kind', v_action,
        'school_id', v_school_id,
        'dish_id', v_dish_id,
        'school_type_id',
          case when v_scope = 'SYSTEM_DISH'
            then v_school_type_id else null end,
        'target_ingredient_id', v_target_ingredient_id,
        'target_recipe_line_id', v_target_recipe_line_id,
        'adjustment_line_id', v_adjustment_line_id,
        'substitute_ingredient_id', v_substitute_id,
        'quantity_per_basis', v_quantity,
        'unit_id', v_unit_id,
        'effective_from', v_effective_from,
        'effective_to', v_effective_to,
        'reason_code', 'LEGACY_IMPORT',
        'reason_note',
          coalesce(
            nullif(pg_catalog.btrim(v_item.value ->> 'reason_note'), ''),
            'Imported OPS v1 business intent; no historical Atlas approval is claimed.'
          ),
        'source_evidence', pg_catalog.jsonb_build_object(
          'source_system', v_source_system,
          'legacy_layer', v_layer,
          'legacy_record_id', v_legacy_id,
          'legacy_is_active', v_is_active,
          'historical_actor_approval_claimed', false
        ),
        'legacy_source', v_layer,
        'legacy_record_id', v_legacy_id,
        'is_active', v_is_active,
        'cancellation_revision_id', v_cancellation_revision_id
      );
      v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment(
        v_row,
        v_effective_from
      );
      if not coalesce((v_validation ->> 'valid')::boolean, false) then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'array', v_array.key,
            'legacy_id', v_legacy_id,
            'blockers', v_validation -> 'blockers'
          )
        );
      end if;
      v_prepared := v_prepared || pg_catalog.jsonb_build_array(v_row);
    end loop;
  end loop;

  v_source_counts := v_source_counts || pg_catalog.jsonb_build_object(
    'total', v_total
  );
  if (
    select pg_catalog.count(*)
    from (
      select row ->> 'legacy_source', row ->> 'legacy_record_id'
      from pg_catalog.jsonb_array_elements(v_prepared) row
      group by row ->> 'legacy_source', row ->> 'legacy_record_id'
      having pg_catalog.count(*) > 1
    ) duplicate
  ) > 0 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'DUPLICATE_LEGACY_IDENTITY',
        'message',
          'A legacy layer and record identity may occur only once per snapshot.'
      )
    );
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_prepared)
      with ordinality left_row(value, position)
    join pg_catalog.jsonb_array_elements(v_prepared)
      with ordinality right_row(value, position)
      on left_row.position < right_row.position
    where left_row.value ->> 'scope_kind'
        = right_row.value ->> 'scope_kind'
      and left_row.value ->> 'school_id'
        is not distinct from right_row.value ->> 'school_id'
      and left_row.value ->> 'dish_id'
        is not distinct from right_row.value ->> 'dish_id'
      and left_row.value ->> 'school_type_id'
        is not distinct from right_row.value ->> 'school_type_id'
      and left_row.value ->> 'target_ingredient_id'
        is not distinct from right_row.value ->> 'target_ingredient_id'
      and left_row.value ->> 'target_recipe_line_id'
        is not distinct from right_row.value ->> 'target_recipe_line_id'
      and (
        left_row.value ->> 'action_kind' <> 'ADD'
        or left_row.value ->> 'adjustment_line_id'
          is not distinct from right_row.value ->> 'adjustment_line_id'
      )
      and pg_catalog.daterange(
        atlas_core.rmvp_02b_safe_date(
          left_row.value ->> 'effective_from'
        ),
        atlas_core.rmvp_02b_safe_date(
          left_row.value ->> 'effective_to'
        ),
        '[)'
      ) && pg_catalog.daterange(
        atlas_core.rmvp_02b_safe_date(
          right_row.value ->> 'effective_from'
        ),
        atlas_core.rmvp_02b_safe_date(
          right_row.value ->> 'effective_to'
        ),
        '[)'
      )
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'OVERLAPPING_IMPORTED_RULES',
        'message',
          'The snapshot contains overlapping active revisions for one exact typed target.'
      )
    );
  end if;

  with recursive edges(source_id, substitute_id, active_period) as (
    select
      (row ->> 'target_ingredient_id')::uuid,
      (row ->> 'substitute_ingredient_id')::uuid,
      pg_catalog.daterange(
        atlas_core.rmvp_02b_safe_date(row ->> 'effective_from'),
        atlas_core.rmvp_02b_safe_date(row ->> 'effective_to'),
        '[)'
      )
    from pg_catalog.jsonb_array_elements(v_prepared) row
    where row ->> 'scope_kind' = 'SYSTEM_INGREDIENT'
      and (row ->> 'is_active')::boolean
    union all
    select
      root.target_ingredient_id,
      revision.substitute_ingredient_id,
      pg_catalog.daterange(
        revision.effective_from,
        revision.effective_to,
        '[)'
      )
    from atlas_admin.recipe_composition_adjustments root
    join atlas_admin.recipe_composition_adjustment_revisions revision
      on revision.recipe_composition_adjustment_revision_id =
        root.current_revision_id
    where root.lifecycle_status = 'ACTIVE'
      and root.scope_kind = 'SYSTEM_INGREDIENT'
  ),
  walk(origin_id, current_id, active_period, path_ids, has_cycle) as (
    select
      edge.source_id,
      edge.substitute_id,
      edge.active_period,
      array[edge.source_id, edge.substitute_id],
      edge.source_id = edge.substitute_id
    from edges edge
    union all
    select
      walk.origin_id,
      edge.substitute_id,
      walk.active_period * edge.active_period,
      walk.path_ids || edge.substitute_id,
      edge.substitute_id = any(walk.path_ids)
    from walk
    join edges edge
      on edge.source_id = walk.current_id
     and edge.active_period && walk.active_period
    where not walk.has_cycle
  )
  select coalesce(pg_catalog.bool_or(walk.has_cycle), false)
  into v_cycle_found
  from walk;
  if v_cycle_found then
    v_cycles := pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', 'REPLACEMENT_CYCLE',
        'message',
          'The imported effective system Ingredient replacement graph contains a cycle.'
      )
    );
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0
     or pg_catalog.jsonb_array_length(v_missing) > 0
     or pg_catalog.jsonb_array_length(v_ambiguities) > 0
     or pg_catalog.jsonb_array_length(v_cycles) > 0 then
    v_result := pg_catalog.jsonb_build_object(
      'status', 'REJECTED',
      'import_batch_id', v_batch_id,
      'source_counts', v_source_counts,
      'operation_counts', pg_catalog.jsonb_build_object(
        'inserted', 0,
        'updated', 0,
        'skipped', 0,
        'rejected', v_total
      ),
      'missing_references', v_missing,
      'ambiguities', v_ambiguities,
      'cycles', v_cycles,
      'validation_errors', v_errors,
      'reconciliation', pg_catalog.jsonb_build_object(
        'source_total', v_total,
        'mapped_total', 0,
        'passed', false
      ),
      'limitations', pg_catalog.jsonb_build_array(
        'Legacy hard-deleted history cannot be reconstructed.'
      )
    );
    insert into atlas_legacy.import_batches (
      import_batch_id,
      source_system,
      snapshot_id,
      snapshot_checksum,
      exported_at,
      import_status,
      source_counts,
      operation_counts,
      missing_references,
      validation_errors,
      reconciliation,
      result_payload,
      completed_at
    ) values (
      v_batch_id,
      v_source_system,
      v_snapshot_id,
      v_checksum,
      v_exported_at,
      'REJECTED',
      v_source_counts,
      pg_catalog.jsonb_build_object(
        'inserted', 0,
        'updated', 0,
        'skipped', 0,
        'rejected', v_total
      ),
      v_missing || v_ambiguities,
      v_errors || v_cycles,
      pg_catalog.jsonb_build_object('passed', false),
      v_result,
      pg_catalog.transaction_timestamp()
    );
    return v_result;
  end if;

  for v_row in
    select value
    from pg_catalog.jsonb_array_elements(v_prepared)
    order by value ->> 'legacy_source', value ->> 'legacy_record_id'
  loop
    if exists (
      select 1
      from atlas_admin.recipe_composition_adjustments root
      where root.legacy_source = v_row ->> 'legacy_source'
        and root.legacy_record_id = v_row ->> 'legacy_record_id'
    ) then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    insert into atlas_admin.recipe_composition_adjustments (
      recipe_composition_adjustment_id,
      scope_kind,
      action_kind,
      school_id,
      dish_id,
      school_type_id,
      target_ingredient_id,
      target_recipe_line_id,
      adjustment_line_id,
      lifecycle_status,
      version,
      legacy_source,
      legacy_record_id,
      created_by_actor_id,
      updated_by_actor_id
    ) values (
      (v_row ->> 'adjustment_id')::uuid,
      v_row ->> 'scope_kind',
      v_row ->> 'action_kind',
      atlas_core.pa_05b_safe_uuid(v_row ->> 'school_id'),
      atlas_core.pa_05b_safe_uuid(v_row ->> 'dish_id'),
      atlas_core.pa_05b_safe_uuid(v_row ->> 'school_type_id'),
      atlas_core.pa_05b_safe_uuid(v_row ->> 'target_ingredient_id'),
      atlas_core.pa_05b_safe_uuid(v_row ->> 'target_recipe_line_id'),
      atlas_core.pa_05b_safe_uuid(v_row ->> 'adjustment_line_id'),
      'ACTIVE',
      1,
      v_row ->> 'legacy_source',
      v_row ->> 'legacy_record_id',
      v_imported_by_actor_id,
      v_imported_by_actor_id
    );
    insert into atlas_admin.recipe_composition_adjustment_revisions (
      recipe_composition_adjustment_revision_id,
      recipe_composition_adjustment_id,
      scope_kind,
      action_kind,
      revision_number,
      revision_status,
      effective_from,
      effective_to,
      substitute_ingredient_id,
      quantity_per_basis,
      unit_id,
      reason_code,
      reason_note,
      source_evidence,
      created_by_actor_id
    ) values (
      (v_row ->> 'revision_id')::uuid,
      (v_row ->> 'adjustment_id')::uuid,
      v_row ->> 'scope_kind',
      v_row ->> 'action_kind',
      1,
      'ACTIVE',
      atlas_core.rmvp_02b_safe_date(v_row ->> 'effective_from'),
      atlas_core.rmvp_02b_safe_date(v_row ->> 'effective_to'),
      atlas_core.pa_05b_safe_uuid(
        v_row ->> 'substitute_ingredient_id'
      ),
      atlas_core.pa_05b_safe_numeric(v_row ->> 'quantity_per_basis'),
      atlas_core.pa_05b_safe_uuid(v_row ->> 'unit_id'),
      'LEGACY_IMPORT',
      v_row ->> 'reason_note',
      v_row -> 'source_evidence',
      v_imported_by_actor_id
    );
    update atlas_admin.recipe_composition_adjustments
    set current_revision_id = (v_row ->> 'revision_id')::uuid,
        current_revision_number = 1
    where recipe_composition_adjustment_id =
      (v_row ->> 'adjustment_id')::uuid;
    if not (v_row ->> 'is_active')::boolean then
      insert into atlas_admin.recipe_composition_adjustment_revisions (
        recipe_composition_adjustment_revision_id,
        recipe_composition_adjustment_id,
        scope_kind,
        action_kind,
        revision_number,
        predecessor_revision_id,
        revision_status,
        effective_from,
        effective_to,
        reason_code,
        reason_note,
        source_evidence,
        created_by_actor_id
      ) values (
        (v_row ->> 'cancellation_revision_id')::uuid,
        (v_row ->> 'adjustment_id')::uuid,
        v_row ->> 'scope_kind',
        v_row ->> 'action_kind',
        2,
        (v_row ->> 'revision_id')::uuid,
        'CANCELLED',
        atlas_core.rmvp_02b_safe_date(v_row ->> 'effective_from'),
        atlas_core.rmvp_02b_safe_date(v_row ->> 'effective_to'),
        'LEGACY_INACTIVE',
        'Imported legacy record was inactive; no historical Atlas cancellation actor is claimed.',
        (v_row -> 'source_evidence')
          || pg_catalog.jsonb_build_object(
            'interpreted_lifecycle', 'CANCELLED'
          ),
        v_imported_by_actor_id
      );
      update atlas_admin.recipe_composition_adjustments
      set current_revision_id =
            (v_row ->> 'cancellation_revision_id')::uuid,
          current_revision_number = 2,
          lifecycle_status = 'CANCELLED',
          version = 2
      where recipe_composition_adjustment_id =
        (v_row ->> 'adjustment_id')::uuid;
    end if;
    v_inserted := v_inserted + 1;
  end loop;

  v_result := pg_catalog.jsonb_build_object(
    'status', 'COMPLETED',
    'import_batch_id', v_batch_id,
    'source_counts', v_source_counts,
    'target_counts', pg_catalog.jsonb_build_object(
      'adjustments', v_inserted
    ),
    'mapping_counts', pg_catalog.jsonb_build_object(
      'typed_adjustment_mappings', v_inserted + v_skipped
    ),
    'operation_counts', pg_catalog.jsonb_build_object(
      'inserted', v_inserted,
      'updated', v_updated,
      'skipped', v_skipped,
      'rejected', 0
    ),
    'missing_references', '[]'::jsonb,
    'ambiguities', '[]'::jsonb,
    'cycles', '[]'::jsonb,
    'reconciliation', pg_catalog.jsonb_build_object(
      'source_total', v_total,
      'mapped_total', v_inserted + v_skipped,
      'passed', v_total = v_inserted + v_skipped
    ),
    'limitations', pg_catalog.jsonb_build_array(
      'Legacy hard-deleted history cannot be reconstructed.',
      'Legacy effective-BOM view rows are not imported as facts.',
      'The import actor records the Atlas migration action, not historical legacy approval.'
    )
  );
  insert into atlas_legacy.import_batches (
    import_batch_id,
    source_system,
    snapshot_id,
    snapshot_checksum,
    exported_at,
    import_status,
    source_counts,
    target_counts,
    mapping_counts,
    operation_counts,
    reconciliation,
    result_payload,
    completed_at
  ) values (
    v_batch_id,
    v_source_system,
    v_snapshot_id,
    v_checksum,
    v_exported_at,
    'COMPLETED',
    v_source_counts,
    v_result -> 'target_counts',
    v_result -> 'mapping_counts',
    v_result -> 'operation_counts',
    v_result -> 'reconciliation',
    v_result,
    pg_catalog.transaction_timestamp()
  );
  return v_result;
exception when others then
  raise;
end;
$$;

grant usage on schema
  atlas_core,
  atlas_admin,
  atlas_audit,
  atlas_api,
  atlas_legacy,
  extensions
to atlas_master_data_command_runtime;

grant execute on function
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_numeric(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(
    jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint
  ),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(
    jsonb, uuid, text, text, text, uuid, uuid, uuid
  ),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean),
  atlas_core.rmvp_01_authorize_global(jsonb, text, text),
  atlas_core.rmvp_01_record_change(
    jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb
  ),
  atlas_core.rmvp_02b_safe_date(text),
  atlas_core.rmvp_02b_validate_command_request(jsonb, text),
  atlas_core.rmvp_02b_prepare_command(jsonb, text, text, text),
  atlas_core.rmvp_02b_adjustment_workbench_payload(),
  atlas_core.rmvp_02b_active_rules(date, uuid, uuid, jsonb, uuid),
  atlas_core.rmvp_02b_transform_line(jsonb, jsonb),
  atlas_core.rmvp_02b_resolve_effective_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  ),
  atlas_core.rmvp_02b_validate_proposed_adjustment(jsonb, date, uuid),
  atlas_core.rmvp_02b_finish_success(
    jsonb, uuid, uuid, text, uuid, bigint, bigint,
    jsonb, jsonb, text
  )
to atlas_master_data_command_runtime;

grant select on
  atlas_core.actors,
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes,
  atlas_core.command_receipts,
  atlas_admin.schools,
  atlas_admin.school_types,
  atlas_admin.dishes,
  atlas_admin.recipes,
  atlas_admin.recipe_versions,
  atlas_admin.recipe_lines,
  atlas_admin.recipe_line_revisions,
  atlas_admin.ingredients,
  atlas_admin.units,
  atlas_admin.recipe_composition_adjustments,
  atlas_admin.recipe_composition_adjustment_revisions
to atlas_master_data_command_runtime;

grant insert, update on atlas_core.command_receipts
  to atlas_master_data_command_runtime;
grant insert (
  recipe_composition_adjustment_id,
  scope_kind,
  action_kind,
  school_id,
  dish_id,
  school_type_id,
  target_ingredient_id,
  target_recipe_line_id,
  adjustment_line_id,
  current_revision_id,
  current_revision_number,
  lifecycle_status,
  version,
  legacy_source,
  legacy_record_id,
  created_by_actor_id,
  updated_by_actor_id,
  updated_at
) on atlas_admin.recipe_composition_adjustments
to atlas_master_data_command_runtime;
grant update (
  current_revision_id,
  current_revision_number,
  lifecycle_status,
  version,
  updated_by_actor_id,
  updated_at
) on atlas_admin.recipe_composition_adjustments
to atlas_master_data_command_runtime;
grant insert (
  recipe_composition_adjustment_revision_id,
  recipe_composition_adjustment_id,
  scope_kind,
  action_kind,
  revision_number,
  predecessor_revision_id,
  revision_status,
  effective_from,
  effective_to,
  substitute_ingredient_id,
  quantity_per_basis,
  unit_id,
  reason_code,
  reason_note,
  source_evidence,
  created_by_actor_id
) on atlas_admin.recipe_composition_adjustment_revisions
to atlas_master_data_command_runtime;

grant insert on
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_master_data_command_runtime;
grant select (domain_event_id) on atlas_audit.domain_events
  to atlas_master_data_command_runtime;
grant select (audit_event_id) on atlas_audit.audit_events
  to atlas_master_data_command_runtime;

create policy rmvp_02b_command_select
on atlas_admin.recipe_composition_adjustments
for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02b_command_insert
on atlas_admin.recipe_composition_adjustments
for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02b_command_update
on atlas_admin.recipe_composition_adjustments
for update to atlas_master_data_command_runtime
using (true) with check (true);
create policy rmvp_02b_command_revision_select
on atlas_admin.recipe_composition_adjustment_revisions
for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02b_command_revision_insert
on atlas_admin.recipe_composition_adjustment_revisions
for insert to atlas_master_data_command_runtime with check (true);

grant usage on schema atlas_core, atlas_admin, atlas_api
  to atlas_read_runtime;
grant execute on function
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_numeric(text),
  atlas_core.rmvp_01_authorize_global(jsonb, text, text),
  atlas_core.rmvp_02b_safe_date(text),
  atlas_core.rmvp_02b_read_error(
    jsonb, text, text, text, jsonb, jsonb
  ),
  atlas_core.rmvp_02b_validate_read_request(jsonb, text),
  atlas_core.rmvp_02b_adjustment_workbench_payload(),
  atlas_core.rmvp_02b_active_rules(date, uuid, uuid, jsonb, uuid),
  atlas_core.rmvp_02b_transform_line(jsonb, jsonb),
  atlas_core.rmvp_02b_resolve_effective_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  ),
  atlas_core.rmvp_02b_validate_proposed_adjustment(jsonb, date, uuid)
to atlas_read_runtime;
grant select on
  atlas_core.actors,
  atlas_admin.schools,
  atlas_admin.school_types,
  atlas_admin.dishes,
  atlas_admin.recipes,
  atlas_admin.recipe_versions,
  atlas_admin.recipe_lines,
  atlas_admin.recipe_line_revisions,
  atlas_admin.ingredients,
  atlas_admin.units,
  atlas_admin.recipe_composition_adjustments,
  atlas_admin.recipe_composition_adjustment_revisions
to atlas_read_runtime;
create policy rmvp_02b_read_select
on atlas_admin.recipe_composition_adjustments
for select to atlas_read_runtime using (true);
create policy rmvp_02b_read_revision_select
on atlas_admin.recipe_composition_adjustment_revisions
for select to atlas_read_runtime using (true);

alter function atlas_core.rmvp_02b_guard_adjustment_history()
  owner to atlas_owner;
alter function atlas_core.rmvp_02b_safe_date(text)
  owner to atlas_owner;
alter function atlas_core.rmvp_02b_read_error(
  jsonb, text, text, text, jsonb, jsonb
) owner to atlas_owner;
alter function atlas_core.rmvp_02b_validate_read_request(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_02b_validate_command_request(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_02b_prepare_command(
  jsonb, text, text, text
) owner to atlas_owner;
alter function atlas_core.rmvp_02b_adjustment_workbench_payload()
  owner to atlas_owner;
alter function atlas_core.rmvp_02b_active_rules(
  date, uuid, uuid, jsonb, uuid
) owner to atlas_owner;
alter function atlas_core.rmvp_02b_transform_line(jsonb, jsonb)
  owner to atlas_owner;
alter function atlas_core.rmvp_02b_resolve_effective_composition(
  date, uuid, uuid, jsonb, uuid, uuid
) owner to atlas_owner;
alter function atlas_core.rmvp_02b_validate_proposed_adjustment(
  jsonb, date, uuid
) owner to atlas_owner;
alter function atlas_core.rmvp_02b_finish_success(
  jsonb, uuid, uuid, text, uuid, bigint, bigint,
  jsonb, jsonb, text
) owner to atlas_owner;
alter function atlas_legacy.import_recipe_adjustment_snapshot(jsonb)
  owner to atlas_owner;

grant atlas_master_data_command_runtime, atlas_read_runtime
  to postgres with set true;
grant create on schema atlas_api to
  atlas_master_data_command_runtime,
  atlas_read_runtime;
alter function atlas_api.get_recipe_adjustment_workbench(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.resolve_effective_recipe_composition(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.preview_recipe_composition_adjustment(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.create_recipe_composition_adjustment(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.supersede_recipe_composition_adjustment(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.cancel_recipe_composition_adjustment(jsonb)
  owner to atlas_master_data_command_runtime;
revoke create on schema atlas_api from
  atlas_master_data_command_runtime,
  atlas_read_runtime;

revoke execute on function
  atlas_core.rmvp_02b_guard_adjustment_history(),
  atlas_core.rmvp_02b_safe_date(text),
  atlas_core.rmvp_02b_read_error(
    jsonb, text, text, text, jsonb, jsonb
  ),
  atlas_core.rmvp_02b_validate_read_request(jsonb, text),
  atlas_core.rmvp_02b_validate_command_request(jsonb, text),
  atlas_core.rmvp_02b_prepare_command(jsonb, text, text, text),
  atlas_core.rmvp_02b_adjustment_workbench_payload(),
  atlas_core.rmvp_02b_active_rules(date, uuid, uuid, jsonb, uuid),
  atlas_core.rmvp_02b_transform_line(jsonb, jsonb),
  atlas_core.rmvp_02b_resolve_effective_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  ),
  atlas_core.rmvp_02b_validate_proposed_adjustment(jsonb, date, uuid),
  atlas_core.rmvp_02b_finish_success(
    jsonb, uuid, uuid, text, uuid, bigint, bigint,
    jsonb, jsonb, text
  )
from public, anon, authenticated, service_role;

revoke execute on function
  atlas_legacy.import_recipe_adjustment_snapshot(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_legacy.import_recipe_adjustment_snapshot(jsonb)
to postgres;

revoke execute on function
  atlas_api.get_recipe_adjustment_workbench(jsonb),
  atlas_api.resolve_effective_recipe_composition(jsonb),
  atlas_api.preview_recipe_composition_adjustment(jsonb),
  atlas_api.create_recipe_composition_adjustment(jsonb),
  atlas_api.supersede_recipe_composition_adjustment(jsonb),
  atlas_api.cancel_recipe_composition_adjustment(jsonb)
from public, anon, service_role;
grant execute on function
  atlas_api.get_recipe_adjustment_workbench(jsonb),
  atlas_api.resolve_effective_recipe_composition(jsonb),
  atlas_api.preview_recipe_composition_adjustment(jsonb),
  atlas_api.create_recipe_composition_adjustment(jsonb),
  atlas_api.supersede_recipe_composition_adjustment(jsonb),
  atlas_api.cancel_recipe_composition_adjustment(jsonb)
to authenticated;

comment on function atlas_api.get_recipe_adjustment_workbench(jsonb) is
  'RMVP-02B authorized adjustment catalog, immutable revisions, typed references, and precedence read.';
comment on function atlas_api.resolve_effective_recipe_composition(jsonb) is
  'RMVP-02B authoritative explicit-date School/Dish Recipe selection and atomic effective BOM resolver.';
comment on function atlas_api.preview_recipe_composition_adjustment(jsonb) is
  'RMVP-02B no-write what-if preview using the same authoritative resolver as persisted rules.';
comment on function atlas_api.create_recipe_composition_adjustment(jsonb) is
  'RMVP-02B command creating one typed adjustment and immutable first revision after an exact-context preview.';
comment on function atlas_api.supersede_recipe_composition_adjustment(jsonb) is
  'RMVP-02B optimistic command appending one direct immutable successor revision without branching.';
comment on function atlas_api.cancel_recipe_composition_adjustment(jsonb) is
  'RMVP-02B optimistic command appending cancellation evidence without deleting adjustment history.';
comment on function atlas_legacy.import_recipe_adjustment_snapshot(jsonb) is
  'RMVP-02B local-postgres-only checksum-bound one-way OPS v1 business-intent import; effective view rows are never imported as facts.';

comment on schema atlas_api is
  'Function-only Atlas Data API boundary; includes reviewed operational, RMVP-01 master-data, RMVP-02A Recipe/BOM, and RMVP-02B adjustment/effective-BOM entry points.';

revoke atlas_master_data_command_runtime, atlas_read_runtime from postgres;
