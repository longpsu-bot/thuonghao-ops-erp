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

  select pg_catalog.count(*)
  into v_exception_count
  from atlas_admin.recipe_composition_adjustments root
  join atlas_admin.schools scoped_school
    on scoped_school.school_id = root.school_id
   and scoped_school.school_status = 'ACTIVE'
  join lateral (
    select revision.revision_status
    from atlas_admin.recipe_composition_adjustment_revisions revision
    where revision.recipe_composition_adjustment_id =
        root.recipe_composition_adjustment_id
      and v_as_of_date >= revision.effective_from
      and (
        revision.effective_to is null
        or v_as_of_date < revision.effective_to
      )
    order by revision.revision_number desc
    limit 1
  ) applicable on applicable.revision_status = 'ACTIVE'
  where root.scope_kind in ('SCHOOL', 'SCHOOL_DISH')
    and (
      root.scope_kind = 'SCHOOL'
      or root.dish_id = v_dish_id
    )
    and scoped_school.school_type_id = v_school_type_id
    and (
      v_school_id is null
      or root.school_id = v_school_id
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
