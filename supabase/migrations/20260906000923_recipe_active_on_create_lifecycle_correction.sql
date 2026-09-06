-- RECIPE-EFFECTIVE final lifecycle correction:
--   * a newly created Dish is immediately ACTIVE at version 1;
--   * its two canonical typed Recipe roots are created in the same transaction;
--   * Recipe Save records Recipe evidence only and never mutates Dish lifecycle.
-- Historical DRAFT rows and the support-only lifecycle command remain compatible.

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
  v_normalized_name text;
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

  v_normalized_name := pg_catalog.lower(pg_catalog.btrim(v_dish_name));
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'atlas-active-dish-name:' || v_normalized_name,
      17404
    )
  );
  if exists (
    select 1
    from atlas_admin.dishes dish
    where dish.dish_status = 'ACTIVE'
      and pg_catalog.lower(pg_catalog.btrim(dish.dish_name)) = v_normalized_name
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'An active Dish already uses this normalized name.',
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
    'ACTIVE',
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
      'dish_status', 'ACTIVE',
      'dish_category', v_category,
      'dish_type_id', v_dish_type_id,
      'display_order', v_display_order,
      'requires_need_generation', v_requires,
      'recipe_ids', v_recipe_ids
    ),
    'Dish and canonical Recipe roots created active and ready for Recipe authoring.',
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
      'The active Dish or canonical Recipe identity is already in use.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Dish and canonical Recipes could not be created safely.',
      'ADMIN',
      v_name
    );
end;
$$;

comment on function atlas_api.create_dish(jsonb) is
  'RMVP-02A.v1 atomic ACTIVE Dish creation with two canonical typed Recipe roots and no RecipeVersion.';

create or replace function atlas_core.uiq03a_finish_success(
  request jsonb,
  p_actor_id uuid,
  p_receipt_id uuid,
  p_event_type text,
  p_recipe_version_id uuid,
  p_version_before bigint,
  p_version_after bigint,
  p_before_summary jsonb,
  p_after_summary jsonb,
  p_safe_message text,
  p_dish_id uuid,
  p_school_type_id uuid
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_recipe_events jsonb;
  v_dish atlas_admin.dishes%rowtype;
  v_response jsonb;
begin
  select dish.* into v_dish
  from atlas_admin.dishes dish
  where dish.dish_id = p_dish_id
  for update;

  v_recipe_events := atlas_core.rmvp_01_record_change(
    request,
    p_actor_id,
    p_receipt_id,
    p_event_type,
    'RecipeVersion',
    p_recipe_version_id,
    p_version_before,
    p_version_after,
    p_before_summary,
    p_after_summary
  );

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02A.v2',
    'command_name', request ->> 'reason_code',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'dish_id', p_dish_id,
      'recipe_version_id', p_recipe_version_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'aggregate_version', p_version_after,
      'dish_version', v_dish.version
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_recipe_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_recipe_events -> 'audit_event_id'
    ),
    'authoritative_readback', atlas_core.uiq03a_workbench_payload(
      p_actor_id, p_dish_id, p_school_type_id
    ),
    'safe_operator_message', p_safe_message,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(p_receipt_id, v_response, true);
end;
$$;

alter function atlas_core.uiq03a_finish_success(
  jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb,
  text, uuid, uuid
) owner to atlas_owner;

comment on function atlas_core.uiq03a_finish_success(
  jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb,
  text, uuid, uuid
) is
  'RMVP-02A.v2 Recipe command finalizer. Records one Recipe event/audit pair and never changes Dish lifecycle; historical DRAFT support remains separate.';

comment on function atlas_api.save_recipe(jsonb) is
  'RMVP-02A.v2 authoritative Recipe Save. Historical DRAFT validations remain compatible, but Save never activates or versions the parent Dish.';
