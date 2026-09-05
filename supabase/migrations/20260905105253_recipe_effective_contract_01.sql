-- RECIPE-EFFECTIVE-CONTRACT-01
-- Central Recipe selection, effective composition contexts, stable effective
-- line targeting, operator history, and atomic Dish-level copy.

set role atlas_owner;

-- Keep the already-proven RMVP-02B transformation engine by OID, but move its
-- current-selection entry point behind the shared selector below. The renamed
-- function remains the selected/historical composition engine.
alter function atlas_core.rmvp_02b_resolve_effective_composition(
  date, uuid, uuid, jsonb, uuid, uuid
) rename to rmvp_02b_resolve_selected_composition;

create function atlas_core.recipe_effective_select_base_recipe(
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
  v_candidate_count bigint;
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

  if target_school_type_id is not null then
    select pg_catalog.count(*)
    into v_candidate_count
    from atlas_admin.recipes recipe
    join atlas_admin.recipe_versions version
      on version.recipe_id = recipe.recipe_id
     and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
    where recipe.dish_id = target_dish_id
      and recipe.school_type_id = target_school_type_id
      and recipe.recipe_status = 'ACTIVE';

    if v_candidate_count > 1 then
      v_blocker_code := 'AMBIGUOUS_SCHOOL_TYPE_RECIPE';
      v_blocker_message :=
        'More than one eligible SchoolType Recipe was found.';
    elsif v_candidate_count = 1 then
      select
        recipe.recipe_id,
        recipe.school_type_id,
        version.recipe_version_id,
        version.basis_portions,
        version.released_at
      into v_selected
      from atlas_admin.recipes recipe
      join atlas_admin.recipe_versions version
        on version.recipe_id = recipe.recipe_id
       and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
      where recipe.dish_id = target_dish_id
        and recipe.school_type_id = target_school_type_id
        and recipe.recipe_status = 'ACTIVE';

      return pg_catalog.jsonb_build_object(
        'status', 'READY',
        'selected_recipe', pg_catalog.jsonb_build_object(
          'dish_id', target_dish_id,
          'school_type_id', v_selected.school_type_id,
          'recipe_id', v_selected.recipe_id,
          'recipe_version_id', v_selected.recipe_version_id,
          'selection_scope', 'SCHOOL_TYPE',
          'basis_portions', v_selected.basis_portions,
          'released_at', v_selected.released_at
        ),
        'blockers', '[]'::jsonb
      );
    end if;
  end if;

  if v_blocker_code is null then
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
      v_blocker_code := 'AMBIGUOUS_GENERAL_RECIPE';
      v_blocker_message := 'More than one eligible general Recipe was found.';
    elsif v_candidate_count = 0 then
      v_blocker_code := 'RECIPE_SELECTION_BLOCKED';
      v_blocker_message :=
        'No eligible released SchoolType or general Recipe was found.';
    else
      select
        recipe.recipe_id,
        recipe.school_type_id,
        version.recipe_version_id,
        version.basis_portions,
        version.released_at
      into v_selected
      from atlas_admin.recipes recipe
      join atlas_admin.recipe_versions version
        on version.recipe_id = recipe.recipe_id
       and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
      where recipe.dish_id = target_dish_id
        and recipe.school_type_id is null
        and recipe.recipe_status = 'ACTIVE';

      return pg_catalog.jsonb_build_object(
        'status', 'READY',
        'selected_recipe', pg_catalog.jsonb_build_object(
          'dish_id', target_dish_id,
          'school_type_id', null,
          'recipe_id', v_selected.recipe_id,
          'recipe_version_id', v_selected.recipe_version_id,
          'selection_scope', 'GENERAL',
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

create function atlas_core.recipe_effective_resolve_composition(
  target_as_of_date date,
  target_school_id uuid,
  target_dish_id uuid,
  target_school_type_id uuid default null,
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
  v_school atlas_admin.schools%rowtype;
  v_dish atlas_admin.dishes%rowtype;
  v_selection jsonb;
  v_resolution jsonb;
  v_warnings jsonb;
begin
  if target_as_of_date is null or target_dish_id is null then
    return pg_catalog.jsonb_build_object(
      'status', 'BLOCKED',
      'as_of_date', target_as_of_date,
      'school_id', target_school_id,
      'school_type_id', target_school_type_id,
      'dish_id', target_dish_id,
      'historical', historical_recipe_version_id is not null,
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
    return pg_catalog.jsonb_build_object(
      'status', 'BLOCKED',
      'as_of_date', target_as_of_date,
      'school_id', target_school_id,
      'school_type_id', target_school_type_id,
      'dish_id', target_dish_id,
      'historical', false,
      'selected_recipe', null,
      'lines', '[]'::jsonb,
      'warnings', '[]'::jsonb,
      'blockers', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'DISH_NOT_FOUND',
          'message', 'The selected Dish does not exist.'
        )
      )
    );
  elsif v_dish.dish_status <> 'ACTIVE' then
    return pg_catalog.jsonb_build_object(
      'status', 'BLOCKED',
      'as_of_date', target_as_of_date,
      'school_id', target_school_id,
      'school_type_id', target_school_type_id,
      'dish_id', target_dish_id,
      'historical', false,
      'selected_recipe', null,
      'lines', '[]'::jsonb,
      'warnings', '[]'::jsonb,
      'blockers', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'DISH_NOT_ELIGIBLE',
          'message', 'The Dish must be active.'
        )
      )
    );
  end if;

  if target_school_id is not null then
    select * into v_school
    from atlas_admin.schools school
    where school.school_id = target_school_id;
    if not found or v_school.school_status <> 'ACTIVE' then
      return pg_catalog.jsonb_build_object(
        'status', 'BLOCKED',
        'as_of_date', target_as_of_date,
        'school_id', target_school_id,
        'school_type_id', null,
        'dish_id', target_dish_id,
        'historical', false,
        'selected_recipe', null,
        'lines', '[]'::jsonb,
        'warnings', '[]'::jsonb,
        'blockers', pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', case when found then 'SCHOOL_INACTIVE'
              else 'SCHOOL_NOT_FOUND' end,
            'message', case when found
              then 'The selected School is not active.'
              else 'The selected School does not exist.' end
          )
        )
      );
    end if;
    target_school_type_id := v_school.school_type_id;
  end if;

  if historical_recipe_version_id is not null then
    return atlas_core.rmvp_02b_resolve_selected_composition(
      target_as_of_date,
      target_school_id,
      target_dish_id,
      proposed_adjustment,
      excluded_adjustment_id,
      historical_recipe_version_id
    );
  end if;

  v_selection := atlas_core.recipe_effective_select_base_recipe(
    target_dish_id,
    target_school_type_id
  );
  if v_selection ->> 'status' <> 'READY' then
    return pg_catalog.jsonb_build_object(
      'status', 'BLOCKED',
      'as_of_date', target_as_of_date,
      'school_id', target_school_id,
      'school_type_id', target_school_type_id,
      'dish_id', target_dish_id,
      'historical', false,
      'selected_recipe', null,
      'lines', '[]'::jsonb,
      'warnings', '[]'::jsonb,
      'blockers', v_selection -> 'blockers'
    );
  end if;

  v_resolution := atlas_core.rmvp_02b_resolve_selected_composition(
    target_as_of_date,
    target_school_id,
    target_dish_id,
    proposed_adjustment,
    excluded_adjustment_id,
    atlas_core.pa_05b_safe_uuid(
      v_selection -> 'selected_recipe' ->> 'recipe_version_id'
    )
  );

  select coalesce(pg_catalog.jsonb_agg(warning), '[]'::jsonb)
  into v_warnings
  from pg_catalog.jsonb_array_elements(
    coalesce(v_resolution -> 'warnings', '[]'::jsonb)
  ) warning
  where warning ->> 'code' <> 'HISTORICAL_SUPPORT_RESOLUTION';

  return pg_catalog.jsonb_set(
    pg_catalog.jsonb_set(
      pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          v_resolution,
          '{historical}',
          'false'::jsonb
        ),
        '{school_type_id}',
        pg_catalog.to_jsonb(target_school_type_id)
      ),
      '{selected_recipe}',
      v_selection -> 'selected_recipe'
    ),
    '{warnings}',
    v_warnings
  );
end;
$$;

create function atlas_core.rmvp_02b_resolve_effective_composition(
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
  return atlas_core.recipe_effective_resolve_composition(
    target_as_of_date,
    target_school_id,
    target_dish_id,
    null,
    proposed_adjustment,
    excluded_adjustment_id,
    historical_recipe_version_id
  );
end;
$$;

comment on function atlas_core.recipe_effective_select_base_recipe(uuid, uuid)
is 'RECIPE-EFFECTIVE-CONTRACT-01 single School-Type then GENERAL released Recipe selector shared by explicit-type and School contexts.';
comment on function atlas_core.recipe_effective_resolve_composition(date, uuid, uuid, uuid, jsonb, uuid, uuid)
is 'RECIPE-EFFECTIVE-CONTRACT-01 explicit-type or authoritative-School composition resolver using one selected base Recipe rule.';

revoke execute on function
  atlas_core.recipe_effective_select_base_recipe(uuid, uuid),
  atlas_core.recipe_effective_resolve_composition(
    date, uuid, uuid, uuid, jsonb, uuid, uuid
  ),
  atlas_core.rmvp_02b_resolve_selected_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  ),
  atlas_core.rmvp_02b_resolve_effective_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  )
from public, anon, authenticated, service_role;

grant execute on function
  atlas_core.recipe_effective_select_base_recipe(uuid, uuid),
  atlas_core.recipe_effective_resolve_composition(
    date, uuid, uuid, uuid, jsonb, uuid, uuid
  ),
  atlas_core.rmvp_02b_resolve_selected_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  ),
  atlas_core.rmvp_02b_resolve_effective_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  )
to atlas_read_runtime, atlas_master_data_command_runtime;

reset role;
