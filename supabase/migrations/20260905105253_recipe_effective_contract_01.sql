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

comment on function atlas_core.recipe_effective_select_base_recipe(uuid, uuid)
is 'RECIPE-EFFECTIVE-CONTRACT-01 single School-Type then GENERAL released Recipe selector shared by explicit-type and School contexts.';
comment on function atlas_core.recipe_effective_resolve_composition(date, uuid, uuid, uuid, jsonb, uuid, uuid)
is 'RECIPE-EFFECTIVE-CONTRACT-01 explicit-type or authoritative-School composition resolver using one selected base Recipe rule.';
comment on function atlas_api.resolve_system_effective_recipe_composition(jsonb)
is 'RECIPE-EFFECTIVE.v1 explicit-date Dish and School-Type system-only effective BOM read.';
comment on function atlas_api.get_recipe_effective_target_context(jsonb)
is 'RECIPE-EFFECTIVE.v1 shaped present-line targets for system School-Type or authoritative School Change Order context.';

revoke execute on function
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

reset role;

grant atlas_read_runtime to postgres with set true;
grant create on schema atlas_api to atlas_read_runtime;

alter function atlas_api.resolve_system_effective_recipe_composition(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.get_recipe_effective_target_context(jsonb)
  owner to atlas_read_runtime;

revoke create on schema atlas_api from atlas_read_runtime;

revoke execute on function
  atlas_api.resolve_system_effective_recipe_composition(jsonb),
  atlas_api.get_recipe_effective_target_context(jsonb)
from public, anon, service_role;
grant execute on function
  atlas_api.resolve_system_effective_recipe_composition(jsonb),
  atlas_api.get_recipe_effective_target_context(jsonb)
to authenticated;

revoke create on schema atlas_core, atlas_api from atlas_read_runtime;
