-- ATLAS DISH CREATION UX: business-only normal creation.
-- Omitted v1 metadata receives defaults; explicit false creation is rejected.
-- Dish lifecycle, approved Menu and eligible Recipe determine demand participation.
-- No persisted-row rewrite, quantity, precedence, role, grant, or RLS change.

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
          'message',
          'A database-backed active Dish Type is required.'
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
  -- Generate only after authorization and receipt replay resolution. The
  -- stable receipt scope above must never depend on fresh random metadata.
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
      'requires_need_generation', v_requires
    ),
    'Dish created as a draft.',
    pg_catalog.jsonb_build_object('dish_id', v_dish_id)
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The dish identity is already in use.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The dish could not be created safely.',
      'ADMIN',
      v_name
    );
end;
$$;

comment on function atlas_api.create_dish(jsonb) is
  'RMVP-02A.v1 Dish creation: omitted code is an opaque server UUID code; omitted display order is 0 and legacy flag is true. Explicit false is rejected; lifecycle determines demand participation.';

-- Surgical changes to existing authoritative paths preserve their current Recipe
-- precedence, historical-evidence guards, quantity formulas and security settings.
-- Fail closed if any predecessor fragment drifts; do not patch an unknown body.
-- The daily presence gate retains inactive references so execution can return the
-- existing explicit correction blocker instead of silently reporting no demand.
do $dish_lifecycle$
declare
  v_patch record;
  v_definition text;
begin
  for v_patch in
    select * from (values
      ('atlas_api.create_need_generation_run(jsonb)', $before$dish.dish_status, dish.requires_need_generation,$before$, $after$dish.dish_status,$after$),
      ('atlas_api.create_need_generation_run(jsonb)', $before$    if not v_menu.requires_need_generation then
      continue;
    end if;
$before$, $after$$after$),
      ('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()', $before$        or not dish.requires_need_generation
$before$, $after$$after$),
      ('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()', $before$  if v_initial_check and exists (
    select 1
    from atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
    join atlas_admin.dishes as dish on dish.dish_id = menu_line.dish_id
    where menu_line.weekly_menu_approval_snapshot_id = v_snapshot.weekly_menu_approval_snapshot_id
      and menu_line.service_date between v_run.period_start and v_run.period_end
      and not dish.requires_need_generation
      and exists (
        select 1
        from atlas_planning.need_generation_recipe_selections as selection
        where selection.need_generation_run_id = v_run.need_generation_run_id
          and selection.weekly_menu_approval_snapshot_line_id = menu_line.weekly_menu_approval_snapshot_line_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Dishes excluded from Need Generation produce no selection';
  end if;
$before$, $after$$after$),
      ('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()', $before$      and dish.requires_need_generation
$before$, $after$$after$),
      ('atlas_core.rmvp_02b_resolve_effective_composition(date,uuid,uuid,jsonb,uuid,uuid)', $before$  elsif v_dish.dish_status <> 'ACTIVE'
        or not v_dish.requires_need_generation then$before$, $after$  elsif v_dish.dish_status <> 'ACTIVE' then$after$),
      ('atlas_core.rmvp_02b_resolve_effective_composition(date,uuid,uuid,jsonb,uuid,uuid)', $before$The Dish must be active and require Need Generation.$before$, $after$The Dish must be active.$after$),
      ('atlas_core.rmvp_03a_menu_issues(date,jsonb)', $before$    where dish.requires_need_generation
      and not exists ($before$, $after$    where not exists ($after$),
      ('atlas_core.rmvp_03a_menu_issues(date,jsonb)', $before$    where dish.requires_need_generation
      and resolution.result ->> 'status' = 'BLOCKED'$before$, $after$    where resolution.result ->> 'status' = 'BLOCKED'$after$),
      ('atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)', $before$        and (
          dish.dish_status <> 'ACTIVE'
          or dish.requires_need_generation
        )
$before$, $after$$after$)
    ) as patches(signature, old_fragment, new_fragment)
  loop
    v_definition := pg_catalog.pg_get_functiondef(v_patch.signature::regprocedure);
    if (pg_catalog.length(v_definition)
        - pg_catalog.length(pg_catalog.replace(v_definition, v_patch.old_fragment, '')))
        / pg_catalog.length(v_patch.old_fragment) <> 1 then
      raise exception 'Dish lifecycle migration: unexpected predecessor for %', v_patch.signature;
    end if;
    execute pg_catalog.replace(v_definition, v_patch.old_fragment, v_patch.new_fragment);
  end loop;
end;
$dish_lifecycle$;
