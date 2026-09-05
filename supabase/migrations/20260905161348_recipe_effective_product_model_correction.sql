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
