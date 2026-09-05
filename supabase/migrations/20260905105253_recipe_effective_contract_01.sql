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

-- RMVP-02B originally derived a School Type only through target_school_id.
-- Carry the explicit authoritative type as private resolver context so a
-- system-only read applies typed SYSTEM_DISH rules without inventing a School.
do $patch$
declare
  v_original text;
  v_patched text;
begin
  v_original := pg_catalog.pg_get_functiondef(
    'atlas_core.rmvp_02b_active_rules(date,uuid,uuid,jsonb,uuid)'
      ::pg_catalog.regprocedure
  );

  v_patched := pg_catalog.replace(
    v_original,
    '  v_school_type_id uuid;',
    '  v_school_type_id uuid := atlas_core.pa_05b_safe_uuid('
      || pg_catalog.chr(10)
      || '    proposed_adjustment ->> ''_target_school_type_id'''
      || pg_catalog.chr(10)
      || '  );'
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE active-rule type context patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
    '            target_school_id is not null'
      || pg_catalog.chr(10)
      || '            and root.school_type_id = v_school_type_id',
    '            root.school_type_id = v_school_type_id'
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE persisted typed-rule patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
    '          target_school_id is not null'
      || pg_catalog.chr(10)
      || '          and atlas_core.pa_05b_safe_uuid('
      || pg_catalog.chr(10)
      || '            proposed_adjustment ->> ''school_type_id'''
      || pg_catalog.chr(10)
      || '          ) = v_school_type_id',
    '          atlas_core.pa_05b_safe_uuid('
      || pg_catalog.chr(10)
      || '            proposed_adjustment ->> ''school_type_id'''
      || pg_catalog.chr(10)
      || '          ) = v_school_type_id'
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE proposed typed-rule patch did not match';
  end if;

  execute v_patched;
end;
$patch$;

alter table atlas_admin.recipe_composition_adjustments
  drop constraint recipe_composition_adjustments_typed_scope_check;
alter table atlas_admin.recipe_composition_adjustments
  add constraint recipe_composition_adjustments_typed_scope_check check (
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
          and (
            (target_recipe_line_id is not null)::integer
            + (adjustment_line_id is not null)::integer = 1
          )
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
          and (
            (target_recipe_line_id is not null)::integer
            + (adjustment_line_id is not null)::integer = 1
          )
        )
      )
    )
  );

create or replace function atlas_core.rmvp_02b_typed_target_lock_key(
  target_scope_kind text,
  target_action_kind text,
  target_school_id uuid,
  target_dish_id uuid,
  target_school_type_id uuid,
  target_ingredient_id uuid,
  target_recipe_line_id uuid,
  target_adjustment_line_id uuid
)
returns bigint
language sql
immutable
security invoker
set search_path = ''
as $$
  select pg_catalog.hashtextextended(
    pg_catalog.jsonb_build_object(
      'contract', 'RMVP-02B_TYPED_TARGET_V1',
      'scope_kind', target_scope_kind,
      'school_id', target_school_id,
      'dish_id', target_dish_id,
      'school_type_id', target_school_type_id,
      'target_kind', case
        when target_scope_kind in ('SYSTEM_INGREDIENT', 'SCHOOL')
          then 'INGREDIENT'
        when target_action_kind = 'ADD'
          then 'OWNS_ADJUSTMENT_LINE'
        when target_recipe_line_id is not null
          then 'RECIPE_LINE'
        else 'ADJUSTMENT_LINE'
      end,
      'target_id', case
        when target_scope_kind in ('SYSTEM_INGREDIENT', 'SCHOOL')
          then target_ingredient_id
        when target_action_kind = 'ADD'
          then target_adjustment_line_id
        when target_recipe_line_id is not null
          then target_recipe_line_id
        else target_adjustment_line_id
      end
    )::text,
    2002002
  );
$$;

do $patch$
declare
  v_original text;
  v_patched text;
begin
  v_original := pg_catalog.pg_get_functiondef(
    'atlas_core.rmvp_02b_validate_proposed_adjustment(jsonb,date,uuid)'
      ::pg_catalog.regprocedure
  );
  v_patched := pg_catalog.replace(
    v_original,
$old$            and v_target_recipe_line_id is not null
            and v_adjustment_line_id is null$old$,
$new$            and (
              (v_target_recipe_line_id is not null)::integer
              + (v_adjustment_line_id is not null)::integer = 1
            )$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE validator XOR patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$               and root.target_recipe_line_id = v_target_recipe_line_id$old$,
$new$               and (
                 (
                   v_target_recipe_line_id is not null
                   and root.target_recipe_line_id = v_target_recipe_line_id
                 )
                 or (
                   v_adjustment_line_id is not null
                   and root.adjustment_line_id = v_adjustment_line_id
                 )
               )$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE validator overlap patch did not match';
  end if;
  execute v_patched;

  v_original := pg_catalog.pg_get_functiondef(
    'atlas_core.rmvp_02b_resolve_selected_composition(date,uuid,uuid,jsonb,uuid,uuid)'
      ::pg_catalog.regprocedure
  );
  v_patched := pg_catalog.replace(
    v_original,
$old$      case
        when item ->> 'action_kind' = 'ADD'
          then 'ADJUSTMENT_LINE'
        else 'RECIPE_LINE'
      end as target_kind,$old$,
$new$      case
        when item ->> 'action_kind' = 'ADD'
          then 'OWNS_ADJUSTMENT_LINE'
        when item ->> 'target_recipe_line_id' is not null
          then 'RECIPE_LINE'
        else 'ADJUSTMENT_LINE'
      end as target_kind,$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE duplicate target-kind patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$      case
        when item ->> 'action_kind' = 'ADD'
          then item ->> 'adjustment_line_id'
        else item ->> 'target_recipe_line_id'
      end as target_id,$old$,
$new$      case
        when item ->> 'action_kind' = 'ADD'
          then item ->> 'adjustment_line_id'
        when item ->> 'target_recipe_line_id' is not null
          then item ->> 'target_recipe_line_id'
        else item ->> 'adjustment_line_id'
      end as target_id,$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE duplicate target-id patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$      case
        when item ->> 'action_kind' = 'ADD'
          then 'ADJUSTMENT_LINE'
        else 'RECIPE_LINE'
      end,
      case
        when item ->> 'action_kind' = 'ADD'
          then item ->> 'adjustment_line_id'
        else item ->> 'target_recipe_line_id'
      end$old$,
$new$      case
        when item ->> 'action_kind' = 'ADD'
          then 'OWNS_ADJUSTMENT_LINE'
        when item ->> 'target_recipe_line_id' is not null
          then 'RECIPE_LINE'
        else 'ADJUSTMENT_LINE'
      end,
      case
        when item ->> 'action_kind' = 'ADD'
          then item ->> 'adjustment_line_id'
        when item ->> 'target_recipe_line_id' is not null
          then item ->> 'target_recipe_line_id'
        else item ->> 'adjustment_line_id'
      end$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE duplicate grouping patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$    order by item ->> 'adjustment_id'$old$,
$new$    order by
      case when item ->> 'action_kind' = 'ADD' then 0 else 1 end,
      item ->> 'adjustment_id'$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE layer ordering patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$        if v_line ->> 'base_recipe_line_id'
             = v_rule ->> 'target_recipe_line_id' then$old$,
$new$        if (
          v_rule ->> 'target_recipe_line_id' is not null
          and v_line ->> 'base_recipe_line_id'
            = v_rule ->> 'target_recipe_line_id'
        ) or (
          v_rule ->> 'target_recipe_line_id' is null
          and v_line ->> 'adjustment_line_id'
            = v_rule ->> 'adjustment_line_id'
        ) then$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE modifier match patch did not match';
  end if;
  execute v_patched;
end;
$patch$;

reset role;

do $patch$
declare
  v_original text;
  v_patched text;
begin
  v_original := pg_catalog.pg_get_functiondef(
    'atlas_api.preview_recipe_composition_adjustment(jsonb)'
      ::pg_catalog.regprocedure
  );
  v_patched := pg_catalog.replace(
    v_original,
$old$  if v_proposal ->> 'action_kind' = 'REPLACE'
     and v_proposal ->> 'target_recipe_line_id' is not null then$old$,
$new$  if v_proposal ->> 'action_kind' = 'REPLACE'
     and (
       v_proposal ->> 'target_recipe_line_id' is not null
       or v_proposal ->> 'adjustment_line_id' is not null
     ) then$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE Preview identity patch did not match';
  end if;
  v_original := v_patched;
  v_patched := pg_catalog.replace(
    v_original,
$old$    where line ->> 'base_recipe_line_id'
      = v_proposal ->> 'target_recipe_line_id';$old$,
$new$    where (
      v_proposal ->> 'target_recipe_line_id' is not null
      and line ->> 'base_recipe_line_id'
        = v_proposal ->> 'target_recipe_line_id'
    ) or (
      v_proposal ->> 'target_recipe_line_id' is null
      and line ->> 'adjustment_line_id'
        = v_proposal ->> 'adjustment_line_id'
    );$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE Preview target lookup patch did not match';
  end if;
  execute v_patched;

  v_original := pg_catalog.pg_get_functiondef(
    'atlas_api.create_recipe_composition_adjustment(jsonb)'
      ::pg_catalog.regprocedure
  );
  v_patched := pg_catalog.replace(
    v_original,
$old$  if v_action = 'REPLACE'
     and v_target_recipe_line_id is not null then$old$,
$new$  if v_action = 'REPLACE'
     and (
       v_target_recipe_line_id is not null
       or v_adjustment_line_id is not null
     ) then$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE Create identity patch did not match';
  end if;
  v_original := v_patched;
  v_patched := pg_catalog.replace(
    v_original,
$old$    where line ->> 'base_recipe_line_id' = v_target_recipe_line_id::text;$old$,
$new$    where (
      v_target_recipe_line_id is not null
      and line ->> 'base_recipe_line_id' = v_target_recipe_line_id::text
    ) or (
      v_target_recipe_line_id is null
      and line ->> 'adjustment_line_id' = v_adjustment_line_id::text
    );$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE Create target lookup patch did not match';
  end if;
  execute v_patched;

  v_original := pg_catalog.pg_get_functiondef(
    'atlas_api.supersede_recipe_composition_adjustment(jsonb)'
      ::pg_catalog.regprocedure
  );
  v_patched := pg_catalog.replace(
    v_original,
$old$  if v_root.action_kind = 'REPLACE'
     and v_root.target_recipe_line_id is not null then$old$,
$new$  if v_root.action_kind = 'REPLACE'
     and (
       v_root.target_recipe_line_id is not null
       or v_root.adjustment_line_id is not null
     ) then$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE Supersede identity patch did not match';
  end if;
  v_original := v_patched;
  v_patched := pg_catalog.replace(
    v_original,
$old$    where line ->> 'base_recipe_line_id'
      = v_root.target_recipe_line_id::text;$old$,
$new$    where (
      v_root.target_recipe_line_id is not null
      and line ->> 'base_recipe_line_id' = v_root.target_recipe_line_id::text
    ) or (
      v_root.target_recipe_line_id is null
      and line ->> 'adjustment_line_id' = v_root.adjustment_line_id::text
    );$new$
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE Supersede target lookup patch did not match';
  end if;
  execute v_patched;
end;
$patch$;

set role atlas_owner;

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
    coalesce(proposed_adjustment, '{}'::jsonb)
      || pg_catalog.jsonb_build_object(
        '_target_school_type_id', target_school_type_id
      ),
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

create function atlas_core.recipe_effective_validate_read_request(
  request jsonb,
  read_name text
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_error jsonb;
begin
  if request is null
     or pg_catalog.jsonb_typeof(request) <> 'object'
     or request ->> 'contract_version'
       is distinct from 'RECIPE-EFFECTIVE.v1' then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RECIPE-EFFECTIVE.v1',
      'error_code', 'VALIDATION_FAILED',
      'safe_message', 'The read requires RECIPE-EFFECTIVE.v1.',
      'domain', 'ADMIN',
      'read_name', read_name,
      'field_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'contract_version',
          'message', 'Use RECIPE-EFFECTIVE.v1.'
        )
      ),
      'blocking_references', '[]'::jsonb,
      'correlation_id', request ->> 'correlation_id'
    );
  end if;

  v_error := atlas_core.rmvp_02b_validate_read_request(
    request || pg_catalog.jsonb_build_object(
      'contract_version', 'RMVP-02B.v1'
    ),
    read_name
  );
  if v_error is not null then
    return pg_catalog.jsonb_set(
      v_error,
      '{contract_version}',
      '"RECIPE-EFFECTIVE.v1"'::jsonb
    );
  end if;
  return null;
end;
$$;

create function atlas_api.resolve_system_effective_recipe_composition(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'resolve_system_effective_recipe_composition';
  v_error jsonb;
  v_context jsonb;
  v_as_of_date date;
  v_dish_id uuid;
  v_school_type_id uuid;
  v_resolution jsonb;
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
  v_school_type_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'school_type_id'
  );
  if v_as_of_date is null
     or v_dish_id is null
     or v_school_type_id is null
     or not exists (
       select 1
       from atlas_admin.school_types school_type
       where school_type.school_type_id = v_school_type_id
         and school_type.school_type_status = 'ACTIVE'
     ) then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RECIPE-EFFECTIVE.v1',
      'error_code', 'VALIDATION_FAILED',
      'safe_message',
        'An explicit date, Dish, and active School Type are required.',
      'domain', 'ADMIN',
      'read_name', v_name,
      'field_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload',
          'message',
            'Supply valid as_of_date, dish_id, and school_type_id.'
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

  v_resolution := atlas_core.recipe_effective_resolve_composition(
    v_as_of_date,
    null,
    v_dish_id,
    v_school_type_id
  );

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'correlation_id', request ->> 'correlation_id',
    'resolution', v_resolution,
    'safe_operator_message',
      'Authorized system-effective Recipe composition returned.'
  );
exception when others then
  return pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'error_code', 'INTERNAL_READ_FAILURE',
    'safe_message',
      'System-effective Recipe composition could not be returned safely.',
    'domain', 'ADMIN',
    'read_name', v_name,
    'field_errors', '[]'::jsonb,
    'blocking_references', '[]'::jsonb,
    'correlation_id', request ->> 'correlation_id'
  );
end;
$$;

create function atlas_api.get_recipe_effective_target_context(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_recipe_effective_target_context';
  v_error jsonb;
  v_context jsonb;
  v_as_of_date date;
  v_dish_id uuid;
  v_school_id uuid;
  v_school_type_id uuid;
  v_resolution jsonb;
  v_effective_lines jsonb;
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
        'Choose exactly one system School-Type or School context.',
      'domain', 'ADMIN',
      'read_name', v_name,
      'field_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload',
          'message',
            'Supply as_of_date, dish_id, and exactly one of school_type_id or school_id.'
        )
      ),
      'blocking_references', '[]'::jsonb,
      'correlation_id', request ->> 'correlation_id'
    );
  end if;

  if v_school_type_id is not null and not exists (
    select 1
    from atlas_admin.school_types school_type
    where school_type.school_type_id = v_school_type_id
      and school_type.school_type_status = 'ACTIVE'
  ) then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RECIPE-EFFECTIVE.v1',
      'error_code', 'VALIDATION_FAILED',
      'safe_message', 'The selected School Type is not active.',
      'domain', 'ADMIN',
      'read_name', v_name,
      'field_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.school_type_id',
          'message', 'Select an active School Type.'
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

  v_resolution := atlas_core.recipe_effective_resolve_composition(
    v_as_of_date,
    v_school_id,
    v_dish_id,
    v_school_type_id
  );

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'ingredient_id', line ->> 'final_ingredient_id',
        'ingredient_name', ingredient.ingredient_name,
        'quantity_per_basis',
          atlas_core.pa_05b_safe_numeric(
            line ->> 'final_quantity_per_basis'
          ),
        'unit_id', line ->> 'final_unit_id',
        'unit_name', unit.unit_name,
        'target_kind', case
          when line ->> 'base_recipe_line_id' is not null
            then 'RECIPE_LINE'
          else 'ADJUSTMENT_LINE'
        end,
        'target_recipe_line_id', line ->> 'base_recipe_line_id',
        'adjustment_line_id', line ->> 'adjustment_line_id',
        'target_id', coalesce(
          line ->> 'base_recipe_line_id',
          line ->> 'adjustment_line_id'
        ),
        'source_layer', line ->> 'source_layer'
      )
      order by ingredient.ingredient_name,
        coalesce(
          line ->> 'base_recipe_line_id',
          line ->> 'adjustment_line_id'
        )
    ),
    '[]'::jsonb
  )
  into v_effective_lines
  from pg_catalog.jsonb_array_elements(
    coalesce(v_resolution -> 'lines', '[]'::jsonb)
  ) line
  join atlas_admin.ingredients ingredient
    on ingredient.ingredient_id = atlas_core.pa_05b_safe_uuid(
      line ->> 'final_ingredient_id'
    )
  join atlas_admin.units unit
    on unit.unit_id = atlas_core.pa_05b_safe_uuid(
      line ->> 'final_unit_id'
    )
  where line ->> 'final_disposition' = 'PRESENT';

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'correlation_id', request ->> 'correlation_id',
    'target_context', pg_catalog.jsonb_build_object(
      'as_of_date', v_as_of_date,
      'dish_id', v_dish_id,
      'school_id', v_school_id,
      'school_type_id', coalesce(
        v_school_type_id,
        atlas_core.pa_05b_safe_uuid(
          v_resolution ->> 'school_type_id'
        )
      ),
      'selected_recipe', v_resolution -> 'selected_recipe',
      'basis_portions',
        v_resolution -> 'selected_recipe' -> 'basis_portions',
      'effective_lines', v_effective_lines,
      'warnings', v_resolution -> 'warnings',
      'blockers', v_resolution -> 'blockers'
    ),
    'safe_operator_message',
      'Authorized effective Change Order targets returned.'
  );
exception when others then
  return pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'error_code', 'INTERNAL_READ_FAILURE',
    'safe_message',
      'Effective Change Order targets could not be returned safely.',
    'domain', 'ADMIN',
    'read_name', v_name,
    'field_errors', '[]'::jsonb,
    'blocking_references', '[]'::jsonb,
    'correlation_id', request ->> 'correlation_id'
  );
end;
$$;

create function atlas_core.recipe_effective_operator_lines(
  resolution jsonb
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'ingredient_id', line ->> 'final_ingredient_id',
        'ingredient_name', ingredient.ingredient_name,
        'quantity_per_basis',
          atlas_core.pa_05b_safe_numeric(
            line ->> 'final_quantity_per_basis'
          ),
        'unit_id', line ->> 'final_unit_id',
        'unit_name', unit.unit_name,
        'target_kind', case
          when line ->> 'base_recipe_line_id' is not null
            then 'RECIPE_LINE'
          else 'ADJUSTMENT_LINE'
        end,
        'target_id', coalesce(
          line ->> 'base_recipe_line_id',
          line ->> 'adjustment_line_id'
        ),
        'target_recipe_line_id', line ->> 'base_recipe_line_id',
        'adjustment_line_id', line ->> 'adjustment_line_id',
        'source_layer', line ->> 'source_layer',
        'lineage', coalesce(line -> 'lineage', '[]'::jsonb)
      )
      order by ingredient.ingredient_name,
        coalesce(
          line ->> 'base_recipe_line_id',
          line ->> 'adjustment_line_id'
        )
    ),
    '[]'::jsonb
  )
  from pg_catalog.jsonb_array_elements(
    coalesce(resolution -> 'lines', '[]'::jsonb)
  ) line
  join atlas_admin.ingredients ingredient
    on ingredient.ingredient_id = atlas_core.pa_05b_safe_uuid(
      line ->> 'final_ingredient_id'
    )
  join atlas_admin.units unit
    on unit.unit_id = atlas_core.pa_05b_safe_uuid(
      line ->> 'final_unit_id'
    )
  where line ->> 'final_disposition' = 'PRESENT';
$$;

create function atlas_core.recipe_effective_history(
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
  v_selection jsonb;
  v_release_date date;
  v_period record;
  v_resolution jsonb;
  v_change_orders jsonb;
  v_periods jsonb := '[]'::jsonb;
begin
  if target_school_id is not null then
    select school.school_type_id
    into target_school_type_id
    from atlas_admin.schools school
    where school.school_id = target_school_id
      and school.school_status = 'ACTIVE';
    if not found then return '[]'::jsonb; end if;
  end if;

  v_selection := atlas_core.recipe_effective_select_base_recipe(
    target_dish_id,
    target_school_type_id
  );
  if v_selection ->> 'status' <> 'READY' then
    return '[]'::jsonb;
  end if;
  v_release_date := (
    v_selection -> 'selected_recipe' ->> 'released_at'
  )::timestamptz::date;

  for v_period in
    with applicable_roots as (
      select root.recipe_composition_adjustment_id
      from atlas_admin.recipe_composition_adjustments root
      where root.scope_kind = 'SYSTEM_INGREDIENT'
        or (
          root.scope_kind = 'SYSTEM_DISH'
          and root.dish_id = target_dish_id
          and (
            root.school_type_id is null
            or root.school_type_id = target_school_type_id
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
    ),
    boundaries as (
      select v_release_date as boundary_date
      union
      select revision.effective_from
      from atlas_admin.recipe_composition_adjustment_revisions revision
      join applicable_roots root using (
        recipe_composition_adjustment_id
      )
      union
      select revision.effective_to
      from atlas_admin.recipe_composition_adjustment_revisions revision
      join applicable_roots root using (
        recipe_composition_adjustment_id
      )
      where revision.effective_to is not null
    )
    select
      boundary_date as period_from,
      pg_catalog.lead(boundary_date) over (
        order by boundary_date
      ) as period_to
    from boundaries
    where boundary_date >= v_release_date
    order by boundary_date
  loop
    v_resolution := atlas_core.recipe_effective_resolve_composition(
      v_period.period_from,
      target_school_id,
      target_dish_id,
      target_school_type_id
    );

    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'adjustment_id', root.recipe_composition_adjustment_id,
          'revision_id',
            revision.recipe_composition_adjustment_revision_id,
          'revision_number', revision.revision_number,
          'revision_status', revision.revision_status,
          'business_event_kind', case
            when revision.revision_status = 'CANCELLED' then 'CANCELLED'
            when revision.revision_number = 1 then 'CREATED'
            else 'CORRECTED'
          end,
          'scope_kind', root.scope_kind,
          'action_kind', root.action_kind,
          'effective_from', revision.effective_from,
          'effective_to', revision.effective_to,
          'reason_code', revision.reason_code,
          'reason', revision.reason_note,
          'issuer', actor.display_name,
          'issued_at', revision.created_at
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
    into v_change_orders
    from atlas_admin.recipe_composition_adjustments root
    join lateral (
      select candidate.*
      from atlas_admin.recipe_composition_adjustment_revisions candidate
      where candidate.recipe_composition_adjustment_id =
          root.recipe_composition_adjustment_id
        and v_period.period_from >= candidate.effective_from
        and (
          candidate.effective_to is null
          or v_period.period_from < candidate.effective_to
        )
      order by candidate.revision_number desc
      limit 1
    ) revision on true
    join atlas_core.actors actor
      on actor.actor_id = revision.created_by_actor_id
    where root.scope_kind = 'SYSTEM_INGREDIENT'
      or (
        root.scope_kind = 'SYSTEM_DISH'
        and root.dish_id = target_dish_id
        and (
          root.school_type_id is null
          or root.school_type_id = target_school_type_id
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
      );

    v_periods := v_periods || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'period_from', v_period.period_from,
        'period_to', v_period.period_to,
        'resolution_status', v_resolution ->> 'status',
        'effective_bom',
          atlas_core.recipe_effective_operator_lines(v_resolution),
        'change_orders', v_change_orders,
        'warnings', coalesce(v_resolution -> 'warnings', '[]'::jsonb),
        'blockers', coalesce(v_resolution -> 'blockers', '[]'::jsonb)
      )
    );
  end loop;

  return v_periods;
end;
$$;

create function atlas_core.recipe_effective_is_effective_temporal_state(
  temporal_state text
)
returns boolean
language sql
immutable
security invoker
set search_path = ''
as $$
  select temporal_state in (
    'ACTIVE',
    'ACTIVE_RESUMED',
    'ACTIVE_CHANGE_SCHEDULED',
    'ACTIVE_CANCELLATION_SCHEDULED'
  );
$$;

alter function atlas_core.uiq03b_recipe_adjustment_operator_payload(date)
  rename to uiq03b_recipe_adjustment_operator_payload_base;

create function atlas_core.uiq03b_recipe_adjustment_operator_payload(
  reference_date date
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with base as (
    select atlas_core.uiq03b_recipe_adjustment_operator_payload_base(
      reference_date
    ) as payload
  ),
  mapped as (
    select coalesce(
      pg_catalog.jsonb_agg(
        row.value || pg_catalog.jsonb_build_object(
          'is_effective_now',
            atlas_core.recipe_effective_is_effective_temporal_state(
              row.value ->> 'temporal_state'
            )
        )
        order by row.ordinality
      ),
      '[]'::jsonb
    ) as rows
    from base
    cross join lateral pg_catalog.jsonb_array_elements(
      coalesce(base.payload -> 'operator_rows', '[]'::jsonb)
    ) with ordinality as row(value, ordinality)
  )
  select (base.payload - 'operator_rows')
    || pg_catalog.jsonb_build_object('operator_rows', mapped.rows)
  from base, mapped;
$$;

create function atlas_api.get_dish_recipe_operator_workbench(
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
  v_as_of_date date;
  v_dish_id uuid;
  v_school_id uuid;
  v_school_type_id uuid;
  v_dish atlas_admin.dishes%rowtype;
  v_dish_type_name text;
  v_resolution jsonb;
  v_exception_count bigint;
  v_operational_lock boolean;
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

  v_resolution := atlas_core.recipe_effective_resolve_composition(
    v_as_of_date,
    v_school_id,
    v_dish_id,
    v_school_type_id
  );
  v_operational_lock := atlas_core.uiq03a_dish_used_operationally(
    v_dish_id
  );

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
      'basis_portions',
        v_resolution -> 'selected_recipe' -> 'basis_portions',
      'editable_state', 'LOCKED_RELEASED',
      'is_editable', false,
      'is_operationally_locked', v_operational_lock,
      'current_effective_bom',
        atlas_core.recipe_effective_operator_lines(v_resolution),
      'school_exception_count', v_exception_count,
      'allowed_actions', case
        when v_resolution ->> 'status' = 'READY'
          then pg_catalog.jsonb_build_array(
            'CREATE_CHANGE_ORDER', 'COPY_DISH_RECIPES'
          )
        else '[]'::jsonb
      end,
      'blockers', coalesce(v_resolution -> 'blockers', '[]'::jsonb),
      'warnings', coalesce(v_resolution -> 'warnings', '[]'::jsonb),
      'history_periods', atlas_core.recipe_effective_history(
        v_as_of_date,
        v_school_id,
        v_dish_id,
        v_school_type_id
      )
    ),
    'safe_operator_message',
      'Authorized effective Dish Recipe workbench returned.'
  );
exception when others then
  return pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'error_code', 'INTERNAL_READ_FAILURE',
    'safe_message',
      'The effective Dish Recipe workbench could not be returned safely.',
    'domain', 'ADMIN',
    'read_name', v_name,
    'field_errors', '[]'::jsonb,
    'blocking_references', '[]'::jsonb,
    'correlation_id', request ->> 'correlation_id'
  );
end;
$$;

reset role;

do $patch$
declare
  v_original text;
  v_patched text;
begin
  v_original := pg_catalog.pg_get_functiondef(
    'atlas_core.uiq03a_rmvp_02a_target_dish_ids(jsonb,text)'
      ::pg_catalog.regprocedure
  );
  v_patched := pg_catalog.replace(
    v_original,
    '    when ''copy_recipe_version'' then',
    '    when ''copy_recipe_version'', ''copy_dish_recipes'' then'
  );
  if v_patched = v_original then
    raise exception 'RECIPE-EFFECTIVE Dish-copy D-038 patch did not match';
  end if;
  execute v_patched;
end;
$patch$;

set role atlas_owner;

create function atlas_api.copy_dish_recipes(request jsonb)
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
  v_target_dish atlas_admin.dishes%rowtype;
  v_scope record;
  v_selection jsonb;
  v_child_request jsonb;
  v_child_response jsonb;
  v_scope_results jsonb := '[]'::jsonb;
  v_child_failure jsonb;
  v_events jsonb;
  v_response jsonb;
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
     or pg_catalog.btrim(coalesce(request ->> 'reason_note', '')) = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Distinct source and target Dishes plus a copy reason are required.',
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
      request, 'INVARIANT_VIOLATION',
      'The source Dish must be active.', 'ADMIN', v_name
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_response, false
    );
  end if;

  select * into v_target_dish
  from atlas_admin.dishes target_dish
  where target_dish.dish_id = v_target_dish_id
  for update;
  if not found or v_target_dish.dish_status <> 'ACTIVE' then
    v_response := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'The target Dish must be active.', 'ADMIN', v_name
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
      request, 'STALE_VERSION',
      'The target Dish changed after preview. Refresh before copying.',
      'ADMIN', v_name, false, '[]'::jsonb, '[]'::jsonb,
      v_target_dish.version
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_response, false
    );
  end if;

  begin
    for v_scope in
      select school_type.school_type_id, school_type.school_type_name
      from atlas_admin.school_types school_type
      where school_type.school_type_status = 'ACTIVE'
        and school_type.school_type_name in ('Tiểu học', 'Trung học')
      order by case school_type.school_type_name
        when 'Tiểu học' then 1
        when 'Trung học' then 2
      end, school_type.school_type_id
    loop
      v_selection := atlas_core.recipe_effective_select_base_recipe(
        v_source_dish_id,
        v_scope.school_type_id
      );
      if v_selection ->> 'status' <> 'READY' then
        if v_selection -> 'blockers'
          @? '$[*] ? (@.code == "RECIPE_SELECTION_BLOCKED")' then
          v_scope_results := v_scope_results || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'school_type_id', v_scope.school_type_id,
              'scope_name', v_scope.school_type_name,
              'status', 'SOURCE_NOT_AVAILABLE'
            )
          );
          continue;
        end if;
        v_child_failure := pg_catalog.jsonb_build_object(
          'school_type_id', v_scope.school_type_id,
          'scope_name', v_scope.school_type_name,
          'error_code', 'SOURCE_RECIPE_AMBIGUOUS',
          'blockers', v_selection -> 'blockers'
        );
        raise exception 'Dish-level Recipe source selection is blocked';
      end if;

      v_child_request := pg_catalog.jsonb_build_object(
        'contract_version', 'RMVP-02A.v1',
        'command_id', pg_catalog.md5(
          request ->> 'command_id' || ':' || v_scope.school_type_id::text
        )::uuid,
        'correlation_id', request ->> 'correlation_id',
        'idempotency_key',
          request ->> 'idempotency_key' || ':scope:'
            || v_scope.school_type_id::text,
        'expected_version', request ->> 'expected_version',
        'requested_by_auth_subject',
          request ->> 'requested_by_auth_subject',
        'requested_at', request ->> 'requested_at',
        'reason_code', request ->> 'reason_code',
        'reason_note', request ->> 'reason_note',
        'payload', pg_catalog.jsonb_build_object(
          'source_recipe_version_id',
            v_selection -> 'selected_recipe' ->> 'recipe_version_id',
          'target_dish_id', v_target_dish_id,
          'target_school_type_id', v_scope.school_type_id
        )
      );
      v_child_response := atlas_api.copy_recipe_version(v_child_request);
      if not coalesce((v_child_response ->> 'success')::boolean, false) then
        v_child_failure := pg_catalog.jsonb_build_object(
          'school_type_id', v_scope.school_type_id,
          'scope_name', v_scope.school_type_name,
          'error_code', v_child_response ->> 'error_code',
          'safe_message', v_child_response ->> 'safe_message'
        );
        raise exception 'Dish-level Recipe child copy failed';
      end if;
      v_scope_results := v_scope_results || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'school_type_id', v_scope.school_type_id,
          'scope_name', v_scope.school_type_name,
          'source_recipe_id',
            v_selection -> 'selected_recipe' ->> 'recipe_id',
          'source_recipe_version_id',
            v_selection -> 'selected_recipe' ->> 'recipe_version_id',
          'source_selection_scope',
            v_selection -> 'selected_recipe' ->> 'selection_scope',
          'target_recipe_id',
            v_child_response #>> '{affected_aggregate_ids,recipe_id}',
          'target_recipe_version_id',
            v_child_response #>> '{affected_aggregate_ids,recipe_version_id}',
          'status', 'COPIED'
        )
      );
    end loop;
  exception when others then
    if v_child_failure is null then
      v_child_failure := pg_catalog.jsonb_build_object(
        'error_code', 'INTERNAL_CHILD_COPY_FAILURE',
        'safe_message', 'A required scope could not be copied safely.'
      );
    end if;
  end;

  if v_child_failure is not null then
    v_response := atlas_core.pa_05b_command_error(
      request,
      'ATOMIC_SCOPE_COPY_FAILED',
      'No Recipe scope was copied because one required scope failed.',
      'ADMIN',
      v_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_child_failure)
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1',
      'scope_results', v_scope_results
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
      'Dish Recipes were copied atomically for every available supported scope.',
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(
    v_receipt_id, v_response, true
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The Dish Recipe copy changed concurrently. Retry the exact request.',
      'ADMIN', v_name, true
    ) || pg_catalog.jsonb_build_object(
      'contract_version', 'RECIPE-EFFECTIVE.v1'
    );
  when others then
    v_response := atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'The Dish Recipe copy could not be completed safely.',
      'ADMIN', v_name
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

comment on function atlas_core.recipe_effective_select_base_recipe(uuid, uuid)
is 'RECIPE-EFFECTIVE-CONTRACT-01 single School-Type then GENERAL released Recipe selector shared by explicit-type and School contexts.';
comment on function atlas_core.recipe_effective_resolve_composition(date, uuid, uuid, uuid, jsonb, uuid, uuid)
is 'RECIPE-EFFECTIVE-CONTRACT-01 explicit-type or authoritative-School composition resolver using one selected base Recipe rule.';
comment on function atlas_api.resolve_system_effective_recipe_composition(jsonb)
is 'RECIPE-EFFECTIVE.v1 explicit-date Dish and School-Type system-only effective BOM read.';
comment on function atlas_api.get_recipe_effective_target_context(jsonb)
is 'RECIPE-EFFECTIVE.v1 shaped present-line targets for system School-Type or authoritative School Change Order context.';
comment on function atlas_core.recipe_effective_history(date, uuid, uuid, uuid)
is 'RECIPE-EFFECTIVE-CONTRACT-01 full effective-BOM periods from immutable Recipe adjustment boundaries.';
comment on function atlas_api.get_dish_recipe_operator_workbench(jsonb)
is 'RECIPE-EFFECTIVE.v1 Dish operator truth with current effective BOM, exception count, actions, blockers, and full history.';
comment on function atlas_api.copy_dish_recipes(jsonb)
is 'RECIPE-EFFECTIVE.v1 atomic Dish-level copy of available Tiểu học and Trung học Recipe scopes using the lower-level RMVP-02A copy command.';

revoke execute on function
  atlas_core.recipe_effective_select_base_recipe(uuid, uuid),
  atlas_core.recipe_effective_resolve_composition(
    date, uuid, uuid, uuid, jsonb, uuid, uuid
  ),
  atlas_core.recipe_effective_validate_read_request(jsonb, text),
  atlas_core.recipe_effective_operator_lines(jsonb),
  atlas_core.recipe_effective_history(date, uuid, uuid, uuid),
  atlas_core.recipe_effective_is_effective_temporal_state(text),
  atlas_core.uiq03b_recipe_adjustment_operator_payload_base(date),
  atlas_core.uiq03b_recipe_adjustment_operator_payload(date),
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
  atlas_core.recipe_effective_validate_read_request(jsonb, text),
  atlas_core.rmvp_02b_resolve_selected_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  ),
  atlas_core.rmvp_02b_resolve_effective_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  )
to atlas_read_runtime, atlas_master_data_command_runtime;

grant execute on function
  atlas_core.recipe_effective_operator_lines(jsonb),
  atlas_core.recipe_effective_history(date, uuid, uuid, uuid),
  atlas_core.recipe_effective_is_effective_temporal_state(text),
  atlas_core.uiq03b_recipe_adjustment_operator_payload_base(date),
  atlas_core.uiq03b_recipe_adjustment_operator_payload(date)
to atlas_read_runtime;

reset role;

grant atlas_read_runtime, atlas_master_data_command_runtime
  to postgres with set true;
grant create on schema atlas_api to
  atlas_read_runtime, atlas_master_data_command_runtime;

alter function atlas_api.resolve_system_effective_recipe_composition(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.get_recipe_effective_target_context(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.get_dish_recipe_operator_workbench(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.copy_dish_recipes(jsonb)
  owner to atlas_master_data_command_runtime;

revoke create on schema atlas_api from
  atlas_read_runtime, atlas_master_data_command_runtime;

revoke execute on function
  atlas_api.resolve_system_effective_recipe_composition(jsonb),
  atlas_api.get_recipe_effective_target_context(jsonb),
  atlas_api.get_dish_recipe_operator_workbench(jsonb),
  atlas_api.copy_dish_recipes(jsonb)
from public, anon, service_role;
grant execute on function
  atlas_api.resolve_system_effective_recipe_composition(jsonb),
  atlas_api.get_recipe_effective_target_context(jsonb),
  atlas_api.get_dish_recipe_operator_workbench(jsonb),
  atlas_api.copy_dish_recipes(jsonb)
to authenticated;

revoke create on schema atlas_core, atlas_api from
  atlas_read_runtime, atlas_master_data_command_runtime;

-- Runtime SET membership is migration-only; restore the hardened posture.
grant atlas_read_runtime, atlas_master_data_command_runtime
  to postgres with set false;
