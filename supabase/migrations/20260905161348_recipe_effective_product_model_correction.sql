-- RECIPE-EFFECTIVE product-model correction.
-- Forward-only: preserve legacy NULL-general evidence while making the new
-- contract authoritative for the two canonical typed Recipe scopes.

set role atlas_owner;

create or replace function atlas_core.recipe_effective_canonical_school_types()
returns table (
  scope_order integer,
  school_type_id uuid,
  school_type_code text,
  school_type_name text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    expected.scope_order,
    school_type.school_type_id,
    school_type.school_type_code,
    school_type.school_type_name
  from (values
    (1, 'v1-school-type-1'::text),
    (2, 'v1-school-type-2'::text)
  ) expected(scope_order, school_type_code)
  join atlas_admin.school_types school_type
    on school_type.school_type_code = expected.school_type_code
   and school_type.school_type_status = 'ACTIVE'
  order by expected.scope_order;
$$;

create or replace function atlas_core.recipe_effective_lock_canonical_school_types()
returns table (
  scope_order integer,
  school_type_id uuid,
  school_type_code text,
  school_type_name text
)
language plpgsql
volatile
security invoker
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'recipe-effective-canonical:' || expected.school_type_code,
      0
    )
  )
  from (values
    (1, 'v1-school-type-1'::text),
    (2, 'v1-school-type-2'::text)
  ) expected(scope_order, school_type_code)
  order by expected.scope_order;

  return query
  select canonical.*
  from atlas_core.recipe_effective_canonical_school_types() canonical
  order by canonical.scope_order;
end;
$$;

create or replace function atlas_core.recipe_effective_select_base_recipe(
  target_dish_id uuid,
  target_school_type_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_school_type record;
  v_root_count bigint;
  v_recipe_id uuid;
  v_version_count bigint;
  v_selected record;
  v_blocker_code text;
  v_blocker_message text;
begin
  if target_dish_id is null then
    return pg_catalog.jsonb_build_object(
      'status', 'BLOCKED',
      'selected_recipe', null,
      'blockers', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'RECIPE_SELECTION_CONTEXT_REQUIRED',
          'message', 'A Dish is required for Recipe selection.'
        )
      )
    );
  end if;

  select canonical.*
  into v_school_type
  from atlas_core.recipe_effective_canonical_school_types() canonical
  where canonical.school_type_id = target_school_type_id;

  if not found then
    return pg_catalog.jsonb_build_object(
      'status', 'BLOCKED',
      'selected_recipe', null,
      'blockers', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'CANONICAL_SCHOOL_TYPE_REQUIRED',
          'message',
            'An active canonical Recipe School Type is required.'
        )
      )
    );
  end if;

  select pg_catalog.count(*)
  into v_root_count
  from atlas_admin.recipes recipe
  where recipe.dish_id = target_dish_id
    and recipe.school_type_id = target_school_type_id
    and recipe.recipe_status = 'ACTIVE';

  if v_root_count = 0 then
    v_blocker_code := 'TYPED_RECIPE_ROOT_MISSING';
    v_blocker_message :=
      'The Dish does not own the required active typed Recipe root.';
  elsif v_root_count > 1 then
    v_blocker_code := 'AMBIGUOUS_SCHOOL_TYPE_RECIPE';
    v_blocker_message :=
      'More than one active Recipe root exists for the School Type.';
  else
    select recipe.recipe_id
    into v_recipe_id
    from atlas_admin.recipes recipe
    where recipe.dish_id = target_dish_id
      and recipe.school_type_id = target_school_type_id
      and recipe.recipe_status = 'ACTIVE';

    select pg_catalog.count(*)
    into v_version_count
    from atlas_admin.recipe_versions version
    where version.recipe_id = v_recipe_id
      and version.recipe_version_status = 'RELEASED_FOR_PLANNING';

    if v_version_count = 0 then
      v_blocker_code := 'RECIPE_SELECTION_BLOCKED';
      v_blocker_message :=
        'The typed Recipe has no released version available for Planning.';
    elsif v_version_count > 1 then
      v_blocker_code := 'AMBIGUOUS_SCHOOL_TYPE_RECIPE';
      v_blocker_message :=
        'More than one released Recipe Version exists for the School Type.';
    else
      select
        version.recipe_version_id,
        version.basis_portions,
        version.released_at
      into v_selected
      from atlas_admin.recipe_versions version
      where version.recipe_id = v_recipe_id
        and version.recipe_version_status = 'RELEASED_FOR_PLANNING';

      return pg_catalog.jsonb_build_object(
        'status', 'READY',
        'selected_recipe', pg_catalog.jsonb_build_object(
          'dish_id', target_dish_id,
          'school_type_id', target_school_type_id,
          'school_type_code', v_school_type.school_type_code,
          'recipe_id', v_recipe_id,
          'recipe_version_id', v_selected.recipe_version_id,
          'selection_scope', 'SCHOOL_TYPE',
          'basis_portions', v_selected.basis_portions,
          'released_at', v_selected.released_at
        ),
        'blockers', '[]'::jsonb
      );
    end if;
  end if;

  return pg_catalog.jsonb_build_object(
    'status', 'BLOCKED',
    'selected_recipe', null,
    'blockers', pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'code', v_blocker_code,
        'message', v_blocker_message
      )
    )
  );
end;
$$;

-- Preserve the pre-RECIPE-EFFECTIVE RMVP-02B selection behavior only for its
-- compatibility surface. New effective reads call the strict selector above.
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
begin
  return atlas_core.rmvp_02b_resolve_selected_composition(
    target_as_of_date,
    target_school_id,
    target_dish_id,
    proposed_adjustment,
    excluded_adjustment_id,
    historical_recipe_version_id
  );
end;
$$;

comment on function atlas_core.recipe_effective_canonical_school_types()
is 'RECIPE-EFFECTIVE.v1 active canonical Recipe School Types resolved only by stable catalog code.';
comment on function atlas_core.recipe_effective_lock_canonical_school_types()
is 'RECIPE-EFFECTIVE.v1 command helper that transaction-locks both canonical Recipe School-Type identities in stable code order before resolving active rows.';
comment on function atlas_core.recipe_effective_select_base_recipe(uuid, uuid)
is 'RECIPE-EFFECTIVE.v1 strict canonical typed released Recipe selector with no NULL-general fallback.';

revoke execute on function
  atlas_core.recipe_effective_canonical_school_types(),
  atlas_core.recipe_effective_lock_canonical_school_types(),
  atlas_core.recipe_effective_select_base_recipe(uuid, uuid),
  atlas_core.rmvp_02b_resolve_effective_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  )
from public, anon, authenticated, service_role;

grant execute on function
  atlas_core.recipe_effective_canonical_school_types(),
  atlas_core.recipe_effective_select_base_recipe(uuid, uuid),
  atlas_core.rmvp_02b_resolve_effective_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  )
to atlas_read_runtime, atlas_master_data_command_runtime,
  atlas_planning_command_runtime;

grant execute on function
  atlas_core.recipe_effective_lock_canonical_school_types()
to atlas_master_data_command_runtime;

reset role;

create or replace function atlas_api.create_dish(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_dish';
  v_payload jsonb := request -> 'payload';
  v_code text := pg_catalog.lower(
    pg_catalog.btrim(coalesce(v_payload ->> 'dish_code', ''))
  );
  v_dish_name text := pg_catalog.btrim(
    coalesce(v_payload ->> 'dish_name', '')
  );
  v_category text := nullif(
    pg_catalog.btrim(coalesce(v_payload ->> 'dish_category', '')),
    ''
  );
  v_dish_type_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'dish_type_id'
  );
  v_notes text := nullif(
    pg_catalog.btrim(coalesce(v_payload ->> 'operational_notes', '')),
    ''
  );
  v_display_order bigint := case when v_payload ? 'display_order'
    then atlas_core.pa_05b_safe_bigint(v_payload ->> 'display_order')
    else 0 end;
  v_requires boolean;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_dish_id uuid;
  v_canonical_count bigint;
  v_recipe_ids jsonb;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  begin
    v_requires := case when v_payload ? 'requires_need_generation'
      then (v_payload ->> 'requires_need_generation')::boolean
      else true end;
  exception when others then
    v_requires := null;
  end;
  if v_requires is distinct from true then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'Dish demand participation is controlled by lifecycle, not a separate flag.',
      'ADMIN', v_name, false,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'field', 'payload.requires_need_generation',
        'message', 'Omit this legacy field or provide true; false is no longer supported.'
      ))
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
     or (v_payload ? 'dish_code' and v_code = '')
     or v_dish_name = ''
     or v_dish_type_id is null
     or v_display_order is null
     or v_display_order < 0
     or v_display_order > 2147483647 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Dish values are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.dish_type_id',
          'message', 'A database-backed active Dish Type is required.'
        )
      )
    );
  end if;

  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    case when v_payload ? 'dish_code' then 'dish-code:' || v_code
      else 'dish-create' end
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  if not exists (
    select 1
    from atlas_admin.dish_types dish_type
    where dish_type.dish_type_id = v_dish_type_id
      and dish_type.dish_type_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The selected Dish Type is unknown or inactive.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;

  select pg_catalog.count(*)
  into v_canonical_count
  from atlas_core.recipe_effective_lock_canonical_school_types();
  if v_canonical_count <> 2 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'The two canonical Recipe School Types are not ready.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;

  if not (v_payload ? 'dish_code') then
    v_code := 'dish-' || pg_catalog.gen_random_uuid()::text;
  end if;
  if exists (
    select 1 from atlas_admin.dishes where dish_code = v_code
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'The dish code is already in use.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;

  insert into atlas_admin.dishes (
    dish_code,
    dish_name,
    dish_category,
    dish_type_id,
    operational_notes,
    dish_status,
    display_order,
    requires_need_generation
  ) values (
    v_code,
    v_dish_name,
    v_category,
    v_dish_type_id,
    v_notes,
    'DRAFT',
    v_display_order::integer,
    v_requires
  )
  returning dish_id into v_dish_id;

  with inserted as (
    insert into atlas_admin.recipes (
      dish_id,
      school_type_id,
      recipe_status
    )
    select
      v_dish_id,
      canonical.school_type_id,
      'ACTIVE'
    from atlas_core.recipe_effective_canonical_school_types() canonical
    order by canonical.scope_order
    returning recipe_id, school_type_id
  )
  select pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'school_type_id', canonical.school_type_id,
      'school_type_code', canonical.school_type_code,
      'recipe_id', inserted.recipe_id
    )
    order by canonical.scope_order
  )
  into v_recipe_ids
  from inserted
  join atlas_core.recipe_effective_canonical_school_types() canonical
    on canonical.school_type_id = inserted.school_type_id;

  if (
    select pg_catalog.count(*)
    from atlas_core.recipe_effective_canonical_school_types()
  ) <> 2 then
    raise exception using
      errcode = '23514',
      message = 'Canonical Recipe School Types changed during Dish creation';
  end if;

  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'DishCreated',
    'Dish',
    v_dish_id,
    null,
    1,
    null,
    pg_catalog.jsonb_build_object(
      'dish_code', v_code,
      'dish_name', v_dish_name,
      'dish_status', 'DRAFT',
      'dish_category', v_category,
      'dish_type_id', v_dish_type_id,
      'display_order', v_display_order,
      'requires_need_generation', v_requires,
      'recipe_ids', v_recipe_ids
    ),
    'Dish and canonical Recipe roots created as drafts.',
    pg_catalog.jsonb_build_object(
      'dish_id', v_dish_id,
      'recipe_ids', v_recipe_ids
    )
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The dish or canonical Recipe identity is already in use.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The dish and canonical Recipes could not be created safely.',
      'ADMIN',
      v_name
    );
end;
$$;

comment on function atlas_api.create_dish(jsonb) is
  'RMVP-02A.v1 atomic Dish creation with two canonical typed Recipe roots and no RecipeVersion.';

set role atlas_owner;

create or replace function atlas_core.recipe_effective_school_exception_count(
  reference_date date,
  target_school_id uuid,
  target_dish_id uuid,
  target_school_type_id uuid
)
returns bigint
language sql
stable
security invoker
set search_path = ''
as $$
  with context_schools as (
    select school.school_id
    from atlas_admin.schools school
    where target_school_id is not null
      and school.school_id = target_school_id
      and school.school_status = 'ACTIVE'
    union all
    select school.school_id
    from atlas_admin.schools school
    where target_school_id is null
      and school.school_type_id = target_school_type_id
      and school.school_status = 'ACTIVE'
  ),
  resolutions as (
    select atlas_core.recipe_effective_resolve_composition(
      reference_date,
      context_school.school_id,
      target_dish_id,
      target_school_type_id
    ) as payload
    from context_schools context_school
  )
  select pg_catalog.count(distinct lineage.value ->> 'adjustment_id')
  from resolutions resolution
  cross join lateral pg_catalog.jsonb_array_elements(
    coalesce(resolution.payload -> 'lines', '[]'::jsonb)
  ) line(value)
  cross join lateral pg_catalog.jsonb_array_elements(
    coalesce(line.value -> 'lineage', '[]'::jsonb)
  ) lineage(value)
  where resolution.payload ->> 'status' = 'READY'
    and lineage.value ->> 'scope_kind' in ('SCHOOL', 'SCHOOL_DISH')
    and nullif(lineage.value ->> 'adjustment_id', '') is not null;
$$;

revoke execute on function
  atlas_core.recipe_effective_school_exception_count(
    date, uuid, uuid, uuid
  )
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.recipe_effective_school_exception_count(
    date, uuid, uuid, uuid
  )
to atlas_read_runtime;

reset role;

create or replace function atlas_api.get_dish_recipe_operator_workbench(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_dish_recipe_operator_workbench';
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_as_of_date date;
  v_dish_id uuid;
  v_school_id uuid;
  v_school_type_id uuid;
  v_dish atlas_admin.dishes%rowtype;
  v_dish_type_name text;
  v_resolution jsonb;
  v_base_authoring jsonb;
  v_exception_count bigint;
  v_operational_lock boolean;
  v_root_ready boolean;
  v_is_editable boolean;
  v_allowed_actions jsonb;
begin
  v_error := atlas_core.recipe_effective_validate_read_request(
    request, v_name
  );
  if v_error is not null then return v_error; end if;

  v_as_of_date := atlas_core.rmvp_02b_safe_date(
    request -> 'payload' ->> 'as_of_date'
  );
  v_dish_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'dish_id'
  );
  v_school_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'school_id'
  );
  v_school_type_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'school_type_id'
  );
  if v_as_of_date is null
     or v_dish_id is null
     or (v_school_id is null) = (v_school_type_id is null) then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RECIPE-EFFECTIVE.v1',
      'error_code', 'VALIDATION_FAILED',
      'safe_message',
        'Choose exactly one system School-Type or School Recipe context.',
      'domain', 'ADMIN',
      'read_name', v_name,
      'field_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload',
          'message',
            'Supply as_of_date, dish_id, and exactly one context identity.'
        )
      ),
      'blocking_references', '[]'::jsonb,
      'correlation_id', request ->> 'correlation_id'
    );
  end if;

  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.recipe_adjustments.read',
    v_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_set(
      v_context -> 'error',
      '{contract_version}',
      '"RECIPE-EFFECTIVE.v1"'::jsonb
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');

  select *
  into v_dish
  from atlas_admin.dishes dish
  where dish.dish_id = v_dish_id;
  if not found then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RECIPE-EFFECTIVE.v1',
      'error_code', 'NOT_FOUND',
      'safe_message', 'The selected Dish was not found.',
      'domain', 'ADMIN',
      'read_name', v_name,
      'field_errors', '[]'::jsonb,
      'blocking_references', '[]'::jsonb,
      'correlation_id', request ->> 'correlation_id'
    );
  end if;

  select dish_type.dish_type_name
  into v_dish_type_name
  from atlas_admin.dish_types dish_type
  where dish_type.dish_type_id = v_dish.dish_type_id;

  if v_school_id is not null then
    select school.school_type_id
    into v_school_type_id
    from atlas_admin.schools school
    where school.school_id = v_school_id
      and school.school_status = 'ACTIVE';
  end if;

  v_operational_lock := atlas_core.uiq03a_dish_used_operationally(
    v_dish_id
  );

  -- Base authoring is resolved directly from the canonical typed root before
  -- strict released-Recipe readiness is considered.
  v_base_authoring := atlas_core.uiq03a_selection_payload(
    v_actor_id,
    v_dish_id,
    v_school_type_id
  );
  v_root_ready := exists (
    select 1
    from atlas_core.recipe_effective_canonical_school_types() canonical
    join atlas_admin.recipes recipe
      on recipe.school_type_id = canonical.school_type_id
     and recipe.dish_id = v_dish_id
     and recipe.recipe_status = 'ACTIVE'
    where canonical.school_type_id = v_school_type_id
  );

  v_resolution := atlas_core.recipe_effective_resolve_composition(
    v_as_of_date,
    v_school_id,
    v_dish_id,
    v_school_type_id
  );

  v_is_editable := not v_operational_lock
    and v_root_ready
    and coalesce(
      (v_base_authoring #>> '{allowed_actions,save_recipe}')::boolean,
      false
    );

  v_allowed_actions := case
    when v_operational_lock and v_resolution ->> 'status' = 'READY'
      then pg_catalog.jsonb_build_array('CREATE_CHANGE_ORDER')
    when not v_operational_lock
      and v_dish.dish_status = 'ACTIVE'
      and v_root_ready
      then pg_catalog.jsonb_build_array('COPY_DISH_RECIPES')
    else '[]'::jsonb
  end;

  v_exception_count := atlas_core.recipe_effective_school_exception_count(
    v_as_of_date,
    v_school_id,
    v_dish_id,
    v_school_type_id
  );

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'correlation_id', request ->> 'correlation_id',
    'workbench', pg_catalog.jsonb_build_object(
      'dish', pg_catalog.jsonb_build_object(
        'dish_id', v_dish.dish_id,
        'dish_name', v_dish.dish_name,
        'dish_type_name', v_dish_type_name,
        'dish_status', v_dish.dish_status
      ),
      'context_kind', case when v_school_id is null
        then 'SYSTEM_SCHOOL_TYPE' else 'SCHOOL' end,
      'as_of_date', v_as_of_date,
      'school_id', v_school_id,
      'school_type_id', v_school_type_id,
      'selected_recipe', v_resolution -> 'selected_recipe',
      'basis_portions', case
        when v_operational_lock
          then v_resolution -> 'selected_recipe' -> 'basis_portions'
        else v_base_authoring -> 'basis_portions'
      end,
      'base_authoring', v_base_authoring,
      'effective_readiness', pg_catalog.jsonb_build_object(
        'status', v_resolution ->> 'status',
        'blockers', coalesce(v_resolution -> 'blockers', '[]'::jsonb),
        'warnings', coalesce(v_resolution -> 'warnings', '[]'::jsonb)
      ),
      'editable_state', case when v_operational_lock
        then 'LOCKED_CHANGE_ORDER' else 'EDITABLE_BASE' end,
      'is_editable', v_is_editable,
      'is_operationally_locked', v_operational_lock,
      'current_effective_bom', case
        when v_resolution ->> 'status' = 'READY'
          then atlas_core.recipe_effective_operator_lines(v_resolution)
        else '[]'::jsonb
      end,
      'school_exception_count', v_exception_count,
      'allowed_actions', v_allowed_actions,
      'blockers', coalesce(v_resolution -> 'blockers', '[]'::jsonb),
      'warnings', coalesce(v_resolution -> 'warnings', '[]'::jsonb),
      'history_periods', case
        when v_resolution ->> 'status' = 'READY'
          then atlas_core.recipe_effective_history(
            v_as_of_date,
            v_school_id,
            v_dish_id,
            v_school_type_id
          )
        else '[]'::jsonb
      end
    ),
    'safe_operator_message',
      'Authorized Dish Recipe operator workbench returned.'
  );
exception when others then
  return pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'error_code', 'INTERNAL_READ_FAILURE',
    'safe_message',
      'The Dish Recipe operator workbench could not be returned safely.',
    'domain', 'ADMIN',
    'read_name', v_name,
    'field_errors', '[]'::jsonb,
    'blocking_references', '[]'::jsonb,
    'correlation_id', request ->> 'correlation_id'
  );
end;
$$;

comment on function atlas_api.get_dish_recipe_operator_workbench(jsonb)
is 'RECIPE-EFFECTIVE.v1 lifecycle-derived editable base or locked Change Order workbench with independent effective readiness.';

set role atlas_owner;

create or replace function atlas_core.recipe_effective_materialize_copy_scope(
  target_recipe_id uuid,
  source_resolution jsonb,
  source_dish_id uuid,
  source_school_type_id uuid,
  source_school_type_code text,
  copy_as_of_date date,
  command_actor_id uuid,
  outer_command_id uuid,
  reason_note text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_predecessor_id uuid;
  v_next_number integer;
  v_composition jsonb;
  v_contributors jsonb;
  v_new_version_id uuid;
  v_line_count integer;
begin
  select version.recipe_version_id
  into v_predecessor_id
  from atlas_admin.recipe_versions version
  where version.recipe_id = target_recipe_id
    and version.recipe_version_status in (
      'RELEASED_FOR_PLANNING', 'LOCKED'
    )
  order by
    (version.recipe_version_status = 'RELEASED_FOR_PLANNING') desc,
    version.version_number desc
  limit 1;

  select coalesce(pg_catalog.max(version.version_number), 0) + 1
  into v_next_number
  from atlas_admin.recipe_versions version
  where version.recipe_id = target_recipe_id;

  with source_lines as (
    select
      line.value,
      atlas_core.pa_05b_safe_uuid(
        line.value ->> 'final_ingredient_id'
      ) as ingredient_id,
      atlas_core.pa_05b_safe_numeric(
        line.value ->> 'final_quantity_per_basis'
      ) as quantity_per_basis,
      atlas_core.pa_05b_safe_uuid(
        line.value ->> 'final_unit_id'
      ) as unit_id
    from pg_catalog.jsonb_array_elements(
      coalesce(source_resolution -> 'lines', '[]'::jsonb)
    ) line(value)
    where line.value ->> 'final_disposition' = 'PRESENT'
  ),
  target_lines as (
    select
      revision.recipe_line_revision_id,
      revision.recipe_line_id,
      revision.ingredient_id,
      revision.quantity_per_basis,
      revision.unit_id,
      revision.operational_note,
      line.line_code
    from atlas_admin.recipe_line_revisions revision
    join atlas_admin.recipe_lines line
      on line.recipe_line_id = revision.recipe_line_id
    where revision.recipe_version_id = v_predecessor_id
      and revision.line_disposition = 'PRESENT'
  ),
  copied as (
    select
      coalesce(target.recipe_line_id, pg_catalog.gen_random_uuid())
        as recipe_line_id,
      target.recipe_line_revision_id
        as predecessor_recipe_line_revision_id,
      source.ingredient_id,
      source.quantity_per_basis,
      source.unit_id,
      'PRESENT'::text as line_disposition,
      target.operational_note,
      coalesce(target.line_code, nullif(source.value ->> 'line_code', ''))
        as line_code,
      atlas_core.pa_05b_safe_uuid(
        source.value ->> 'base_recipe_line_revision_id'
      ) as source_recipe_line_revision_id,
      source.value ->> 'source_layer' as source_layer,
      coalesce(source.value -> 'lineage', '[]'::jsonb)
        as source_lineage
    from source_lines source
    left join target_lines target
      on target.ingredient_id = source.ingredient_id
  ),
  removed as (
    select
      target.recipe_line_id,
      target.recipe_line_revision_id
        as predecessor_recipe_line_revision_id,
      target.ingredient_id,
      0::numeric as quantity_per_basis,
      target.unit_id,
      'REMOVED'::text as line_disposition,
      target.operational_note,
      target.line_code,
      null::uuid as source_recipe_line_revision_id,
      'TARGET_PREDECESSOR'::text as source_layer,
      '[]'::jsonb as source_lineage
    from target_lines target
    where not exists (
      select 1
      from source_lines source
      where source.ingredient_id = target.ingredient_id
    )
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'recipe_line_id', composition.recipe_line_id,
        'predecessor_recipe_line_revision_id',
          composition.predecessor_recipe_line_revision_id,
        'ingredient_id', composition.ingredient_id,
        'quantity_per_basis', composition.quantity_per_basis,
        'unit_id', composition.unit_id,
        'line_disposition', composition.line_disposition,
        'operational_note', composition.operational_note,
        'line_code', composition.line_code,
        'source_recipe_line_revision_id',
          composition.source_recipe_line_revision_id,
        'source_layer', composition.source_layer,
        'source_lineage', composition.source_lineage
      )
      order by composition.line_disposition, composition.ingredient_id
    ),
    '[]'::jsonb
  )
  into v_composition
  from (
    select * from copied
    union all
    select * from removed
  ) composition;

  v_line_count := (
    select pg_catalog.count(*)::integer
    from pg_catalog.jsonb_array_elements(v_composition) item
    where item ->> 'line_disposition' = 'PRESENT'
  );

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'adjustment_id', contributor.adjustment_id,
        'revision_id', contributor.revision_id
      )
      order by contributor.adjustment_id, contributor.revision_id
    ),
    '[]'::jsonb
  )
  into v_contributors
  from (
    select distinct
      lineage.value ->> 'adjustment_id' as adjustment_id,
      lineage.value ->> 'revision_id' as revision_id
    from pg_catalog.jsonb_array_elements(
      coalesce(source_resolution -> 'lines', '[]'::jsonb)
    ) line(value)
    cross join lateral pg_catalog.jsonb_array_elements(
      coalesce(line.value -> 'lineage', '[]'::jsonb)
    ) lineage(value)
    where lineage.value ->> 'scope_kind' in (
        'SYSTEM_INGREDIENT', 'SYSTEM_DISH'
      )
      and nullif(lineage.value ->> 'adjustment_id', '') is not null
      and nullif(lineage.value ->> 'revision_id', '') is not null
  ) contributor;

  insert into atlas_admin.recipe_lines (
    recipe_line_id,
    recipe_id,
    line_code
  )
  select
    atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id'),
    target_recipe_id,
    nullif(item ->> 'line_code', '')
  from pg_catalog.jsonb_array_elements(v_composition) item
  where not exists (
    select 1
    from atlas_admin.recipe_lines line
    where line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
      item ->> 'recipe_line_id'
    )
  );

  insert into atlas_admin.recipe_versions (
    recipe_id,
    version_number,
    predecessor_recipe_version_id,
    basis_portions,
    recipe_version_status,
    created_by_actor_id,
    draft_composition,
    source_evidence
  ) values (
    target_recipe_id,
    v_next_number,
    v_predecessor_id,
    (source_resolution -> 'selected_recipe' ->> 'basis_portions')::integer,
    'DRAFT',
    command_actor_id,
    v_composition,
    pg_catalog.jsonb_build_object(
      'source_kind', 'RECIPE_EFFECTIVE_COPY',
      'source_dish_id', source_dish_id,
      'source_school_type_id', source_school_type_id,
      'source_school_type_code', source_school_type_code,
      'copy_as_of_date', copy_as_of_date,
      'source_recipe_id',
        source_resolution -> 'selected_recipe' ->> 'recipe_id',
      'source_recipe_version_id',
        source_resolution -> 'selected_recipe' ->> 'recipe_version_id',
      'contributing_system_adjustments', v_contributors,
      'outer_command_id', outer_command_id,
      'reason_note', reason_note
    )
  )
  returning recipe_version_id into v_new_version_id;

  return pg_catalog.jsonb_build_object(
    'target_recipe_id', target_recipe_id,
    'target_recipe_version_id', v_new_version_id,
    'predecessor_recipe_version_id', v_predecessor_id,
    'line_count', v_line_count
  );
end;
$$;

revoke execute on function atlas_core.recipe_effective_materialize_copy_scope(
  uuid, jsonb, uuid, uuid, text, date, uuid, uuid, text
) from public, anon, authenticated, service_role;
grant execute on function atlas_core.recipe_effective_materialize_copy_scope(
  uuid, jsonb, uuid, uuid, text, date, uuid, uuid, text
) to atlas_master_data_command_runtime;

reset role;

create or replace function atlas_api.copy_dish_recipes(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'copy_dish_recipes';
  v_normalized jsonb := request || pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02A.v1'
  );
  v_error jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_source_dish_id uuid := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'source_dish_id'
  );
  v_target_dish_id uuid := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'target_dish_id'
  );
  v_as_of_date date := atlas_core.rmvp_02b_safe_date(
    request -> 'payload' ->> 'as_of_date'
  );
  v_target_dish atlas_admin.dishes%rowtype;
  v_scope record;
  v_target_recipe_id uuid;
  v_resolution jsonb;
  v_resolved_scopes jsonb := '[]'::jsonb;
  v_scope_results jsonb := '[]'::jsonb;
  v_materialized jsonb;
  v_failure jsonb;
  v_events jsonb;
  v_response jsonb;
  v_canonical_count bigint;
begin
  v_error := atlas_core.rmvp_02a_validate_command_request(
    v_normalized,
    v_name
  );
  if v_error is not null then
    return v_error || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
  end if;
  if v_source_dish_id is null
     or v_target_dish_id is null
     or v_source_dish_id = v_target_dish_id
     or v_as_of_date is null
     or pg_catalog.btrim(coalesce(request ->> 'reason_note', '')) = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Distinct source and target Dishes, an explicit date, and a copy reason are required.',
      'ADMIN',
      v_name
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
  end if;

  v_prepare := atlas_core.rmvp_02a_prepare_command(
    v_normalized,
    v_name,
    'master_data.recipes.write',
    'dish-recipe-copy:' || v_target_dish_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return (v_prepare -> 'response') || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  if not exists (
    select 1
    from atlas_admin.dishes source_dish
    where source_dish.dish_id = v_source_dish_id
      and source_dish.dish_status = 'ACTIVE'
  ) then
    v_response := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'The source Dish must be active.',
      'ADMIN',
      v_name
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_response, false
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_target_dish_id::text, 17403)
  );
  select *
  into v_target_dish
  from atlas_admin.dishes target_dish
  where target_dish.dish_id = v_target_dish_id
  for update;
  if not found or v_target_dish.dish_status <> 'ACTIVE' then
    v_response := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'The target Dish must be active.',
      'ADMIN',
      v_name
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_response, false
    );
  end if;
  if v_target_dish.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    v_response := atlas_core.pa_05b_command_error(
      request,
      'STALE_VERSION',
      'The target Dish changed after preview. Refresh before copying.',
      'ADMIN',
      v_name,
      false,
      '[]'::jsonb,
      '[]'::jsonb,
      v_target_dish.version
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_response, false
    );
  end if;
  if atlas_core.uiq03a_dish_used_operationally(v_target_dish_id) then
    v_response := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'The target Dish is locked by approved Menu evidence.',
      'ADMIN',
      v_name
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_response, false
    );
  end if;

  select pg_catalog.count(*)
  into v_canonical_count
  from atlas_core.recipe_effective_lock_canonical_school_types();
  if v_canonical_count <> 2 then
    v_response := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'The two canonical Recipe School Types are not ready.',
      'ADMIN',
      v_name
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_response, false
    );
  end if;

  for v_scope in
    select canonical.*
    from atlas_core.recipe_effective_canonical_school_types() canonical
    order by canonical.scope_order
  loop
    v_resolution := atlas_core.recipe_effective_resolve_composition(
      v_as_of_date,
      null,
      v_source_dish_id,
      v_scope.school_type_id
    );
    if v_resolution ->> 'status' <> 'READY' then
      v_failure := pg_catalog.jsonb_build_object(
        'school_type_id', v_scope.school_type_id,
        'school_type_code', v_scope.school_type_code,
        'error_code', 'SOURCE_RECIPE_NOT_READY',
        'blockers', v_resolution -> 'blockers'
      );
      exit;
    end if;

    if coalesce(v_resolution -> 'lines', '[]'::jsonb)
      @? '$[*].lineage[*] ? (@.scope_kind == "SCHOOL" || @.scope_kind == "SCHOOL_DISH")' then
      v_failure := pg_catalog.jsonb_build_object(
        'school_type_id', v_scope.school_type_id,
        'school_type_code', v_scope.school_type_code,
        'error_code', 'SCHOOL_LAYER_IN_SYSTEM_COPY'
      );
      exit;
    end if;

    select recipe.recipe_id
    into v_target_recipe_id
    from atlas_admin.recipes recipe
    where recipe.dish_id = v_target_dish_id
      and recipe.school_type_id = v_scope.school_type_id
      and recipe.recipe_status = 'ACTIVE'
    for update;
    if not found then
      v_failure := pg_catalog.jsonb_build_object(
        'school_type_id', v_scope.school_type_id,
        'school_type_code', v_scope.school_type_code,
        'error_code', 'TARGET_RECIPE_ROOT_MISSING'
      );
      exit;
    end if;

    if exists (
      select 1
      from atlas_admin.recipe_versions version
      where version.recipe_id = v_target_recipe_id
        and version.recipe_version_status in ('DRAFT', 'VALIDATED')
    ) then
      v_failure := pg_catalog.jsonb_build_object(
        'school_type_id', v_scope.school_type_id,
        'school_type_code', v_scope.school_type_code,
        'error_code', 'TARGET_RECIPE_UNFINISHED'
      );
      exit;
    end if;

    if exists (
      select 1
      from pg_catalog.jsonb_array_elements(
        coalesce(v_resolution -> 'lines', '[]'::jsonb)
      ) line(value)
      left join atlas_admin.ingredients ingredient
        on ingredient.ingredient_id = atlas_core.pa_05b_safe_uuid(
          line.value ->> 'final_ingredient_id'
        )
      left join atlas_admin.units unit
        on unit.unit_id = atlas_core.pa_05b_safe_uuid(
          line.value ->> 'final_unit_id'
        )
      where line.value ->> 'final_disposition' = 'PRESENT'
        and (
          ingredient.ingredient_id is null
          or ingredient.ingredient_status <> 'ACTIVE'
          or unit.unit_id is null
          or unit.unit_status <> 'ACTIVE'
        )
    ) then
      v_failure := pg_catalog.jsonb_build_object(
        'school_type_id', v_scope.school_type_id,
        'school_type_code', v_scope.school_type_code,
        'error_code', 'SOURCE_REFERENCE_INACTIVE'
      );
      exit;
    end if;

    v_resolved_scopes := v_resolved_scopes
      || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'scope_order', v_scope.scope_order,
        'school_type_id', v_scope.school_type_id,
        'school_type_code', v_scope.school_type_code,
        'school_type_name', v_scope.school_type_name,
        'target_recipe_id', v_target_recipe_id,
        'resolution', v_resolution
      ));
  end loop;

  if v_failure is not null
     or pg_catalog.jsonb_array_length(v_resolved_scopes) <> 2 then
    v_response := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'Both canonical source and target Recipe scopes must be ready before copying.',
      'ADMIN',
      v_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(coalesce(
        v_failure,
        pg_catalog.jsonb_build_object('error_code', 'CANONICAL_SCOPE_GAP')
      ))
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_response, false
    );
  end if;

  begin
    for v_scope in
      select item.value
      from pg_catalog.jsonb_array_elements(v_resolved_scopes) item(value)
      order by (item.value ->> 'scope_order')::integer
    loop
      v_materialized := atlas_core.recipe_effective_materialize_copy_scope(
        atlas_core.pa_05b_safe_uuid(
          v_scope.value ->> 'target_recipe_id'
        ),
        v_scope.value -> 'resolution',
        v_source_dish_id,
        atlas_core.pa_05b_safe_uuid(
          v_scope.value ->> 'school_type_id'
        ),
        v_scope.value ->> 'school_type_code',
        v_as_of_date,
        v_actor_id,
        atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
        request ->> 'reason_note'
      );
      v_scope_results := v_scope_results
        || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'school_type_id', v_scope.value ->> 'school_type_id',
          'school_type_code', v_scope.value ->> 'school_type_code',
          'scope_name', v_scope.value ->> 'school_type_name',
          'source_recipe_id',
            v_scope.value #>> '{resolution,selected_recipe,recipe_id}',
          'source_recipe_version_id',
            v_scope.value #>> '{resolution,selected_recipe,recipe_version_id}',
          'source_selection_scope', 'SCHOOL_TYPE',
          'target_recipe_id', v_materialized ->> 'target_recipe_id',
          'target_recipe_version_id',
            v_materialized ->> 'target_recipe_version_id',
          'status', 'COPIED'
        ));
    end loop;
  exception when others then
    v_failure := pg_catalog.jsonb_build_object(
      'error_code', 'ATOMIC_SCOPE_MATERIALIZATION_FAILED'
    );
  end;

  if v_failure is not null then
    v_response := atlas_core.pa_05b_command_error(
      request,
      'ATOMIC_SCOPE_COPY_FAILED',
      'No Recipe scope was copied because materialization failed.',
      'ADMIN',
      v_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_failure)
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_response, false
    );
  end if;

  v_events := atlas_core.rmvp_01_record_change(
    request,
    v_actor_id,
    v_receipt_id,
    'DishRecipesCopied',
    'DishRecipeCopy',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    null,
    1,
    null,
    pg_catalog.jsonb_build_object(
      'source_dish_id', v_source_dish_id,
      'target_dish_id', v_target_dish_id,
      'copy_as_of_date', v_as_of_date,
      'scope_results', v_scope_results
    )
  );
  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'source_dish_id', v_source_dish_id,
      'target_dish_id', v_target_dish_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'aggregate_version', 1
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'audit_event_id'
    ),
    'scope_results', v_scope_results,
    'safe_operator_message',
      'Both canonical Recipe scopes were copied as dated system-effective snapshots.',
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(
    v_receipt_id, v_response, true
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Dish Recipe copy changed concurrently. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
  when others then
    v_response := atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Dish Recipe copy could not be completed safely.',
      'ADMIN',
      v_name
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    if v_receipt_id is not null then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id, v_response, false
      );
    end if;
    return v_response;
end;
$$;

comment on function atlas_api.copy_dish_recipes(jsonb)
is 'RECIPE-EFFECTIVE.v1 atomic dated snapshot of both canonical system-effective BOMs into pre-provisioned target Recipe roots.';

set role atlas_owner;

do $history_base$
begin
  if pg_catalog.to_regprocedure(
    'atlas_core.recipe_effective_history_candidate_base(date,uuid,uuid,uuid)'
  ) is null then
    alter function atlas_core.recipe_effective_history(
      date, uuid, uuid, uuid
    ) rename to recipe_effective_history_candidate_base;
  end if;
end;
$history_base$;

create or replace function atlas_core.recipe_effective_history(
  reference_date date,
  target_school_id uuid,
  target_dish_id uuid,
  target_school_type_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_candidate_periods jsonb;
  v_relevant_adjustment_ids text[];
  v_period record;
  v_filtered_change_orders jsonb;
  v_current jsonb;
  v_last jsonb;
  v_merged_change_orders jsonb;
  v_periods jsonb := '[]'::jsonb;
begin
  v_candidate_periods :=
    atlas_core.recipe_effective_history_candidate_base(
      reference_date,
      target_school_id,
      target_dish_id,
      target_school_type_id
    );

  select pg_catalog.array_agg(distinct lineage.value ->> 'adjustment_id')
  into v_relevant_adjustment_ids
  from pg_catalog.jsonb_array_elements(
    coalesce(v_candidate_periods, '[]'::jsonb)
  ) period(value)
  cross join lateral pg_catalog.jsonb_array_elements(
    coalesce(period.value -> 'effective_bom', '[]'::jsonb)
  ) line(value)
  cross join lateral pg_catalog.jsonb_array_elements(
    coalesce(line.value -> 'lineage', '[]'::jsonb)
  ) lineage(value)
  where nullif(lineage.value ->> 'adjustment_id', '') is not null;

  for v_period in
    select period.value
    from pg_catalog.jsonb_array_elements(
      coalesce(v_candidate_periods, '[]'::jsonb)
    ) period(value)
    order by (period.value ->> 'period_from')::date
  loop
    select coalesce(
      pg_catalog.jsonb_agg(change_order.value order by change_order.ordinality),
      '[]'::jsonb
    )
    into v_filtered_change_orders
    from pg_catalog.jsonb_array_elements(
      coalesce(v_period.value -> 'change_orders', '[]'::jsonb)
    ) with ordinality change_order(value, ordinality)
    where change_order.value ->> 'adjustment_id'
      = any(coalesce(v_relevant_adjustment_ids, array[]::text[]));

    v_current := pg_catalog.jsonb_set(
      v_period.value,
      '{change_orders}',
      v_filtered_change_orders
    );

    if v_last is null then
      v_last := v_current;
    elsif v_last -> 'effective_bom' = v_current -> 'effective_bom'
      and v_last ->> 'resolution_status'
        = v_current ->> 'resolution_status'
      and v_last -> 'blockers' = v_current -> 'blockers'
      and v_last -> 'warnings' = v_current -> 'warnings' then
      select coalesce(
        pg_catalog.jsonb_agg(
          evidence.value
          order by
            evidence.value ->> 'effective_from',
            (evidence.value ->> 'revision_number')::integer,
            evidence.value ->> 'adjustment_id'
        ),
        '[]'::jsonb
      )
      into v_merged_change_orders
      from (
        select distinct on (
          item.value ->> 'adjustment_id',
          item.value ->> 'revision_id'
        ) item.value
        from pg_catalog.jsonb_array_elements(
          coalesce(v_last -> 'change_orders', '[]'::jsonb)
          || coalesce(v_current -> 'change_orders', '[]'::jsonb)
        ) item(value)
        order by
          item.value ->> 'adjustment_id',
          item.value ->> 'revision_id'
      ) evidence;

      v_last := pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          v_last,
          '{period_to}',
          coalesce(v_current -> 'period_to', 'null'::jsonb)
        ),
        '{change_orders}',
        v_merged_change_orders
      );
    else
      v_periods := v_periods || pg_catalog.jsonb_build_array(v_last);
      v_last := v_current;
    end if;
  end loop;

  if v_last is not null then
    v_periods := v_periods || pg_catalog.jsonb_build_array(v_last);
  end if;
  return v_periods;
end;
$$;

comment on function atlas_core.recipe_effective_history(
  date, uuid, uuid, uuid
) is 'RECIPE-EFFECTIVE.v1 materially applicable Dish history with identical adjacent BOM periods coalesced and immutable revision evidence retained.';

revoke execute on function
  atlas_core.recipe_effective_history(date, uuid, uuid, uuid)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.recipe_effective_history(date, uuid, uuid, uuid)
to atlas_read_runtime;

reset role;
