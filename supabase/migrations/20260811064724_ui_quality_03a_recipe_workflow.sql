-- UI-QUALITY-03A: restore the v1 creation-and-lock Recipe workflow.
-- Existing RMVP-02A.v1 functions remain physically callable.

grant atlas_master_data_command_runtime, atlas_read_runtime
  to postgres with set true;
grant usage on schema atlas_planning
  to atlas_master_data_command_runtime;
grant select (dish_id)
  on atlas_planning.weekly_menu_approval_snapshot_lines
  to atlas_master_data_command_runtime;
grant create on schema atlas_core, atlas_api
  to atlas_master_data_command_runtime;
set role atlas_master_data_command_runtime;

create function atlas_core.uiq03a_error(
  request jsonb,
  operation_name text,
  error_code text,
  safe_message text,
  retryable boolean default false,
  actual_version bigint default null
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.jsonb_strip_nulls(pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RMVP-02A.v2',
    'operation_name', operation_name,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'error_code', error_code,
    'safe_message', safe_message,
    'retryable', retryable,
    'actual_version', actual_version,
    'write_certainty', 'NO_COMMITTED_CHANGE',
    'refresh_read', 'get_dish_recipe_workbench'
  ));
$$;

create function atlas_core.uiq03a_validate_read(
  request jsonb,
  read_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_payload jsonb := request -> 'payload';
begin
  if request is null
    or pg_catalog.jsonb_typeof(request) <> 'object'
    or request ->> 'contract_version' is distinct from 'RMVP-02A.v2'
    or atlas_core.pa_05b_safe_uuid(
      request ->> 'requested_by_auth_subject'
    ) is null
    or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
    or pg_catalog.jsonb_typeof(v_payload) is distinct from 'object'
    or v_payload - array['dish_id', 'school_type_id'] <> '{}'::jsonb
    or (
      v_payload ? 'dish_id'
      and v_payload -> 'dish_id' <> 'null'::jsonb
      and atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id') is null
    )
    or (
      v_payload ? 'school_type_id'
      and v_payload -> 'school_type_id' <> 'null'::jsonb
      and atlas_core.pa_05b_safe_uuid(v_payload ->> 'school_type_id') is null
    )
  then
    return atlas_core.uiq03a_error(
      request,
      read_name,
      'VALIDATION_FAILED',
      'Yêu cầu đọc công thức chưa hợp lệ.'
    );
  end if;
  return null;
end;
$$;

create function atlas_core.uiq03a_validate_command(
  request jsonb,
  command_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_payload jsonb := request -> 'payload';
  v_line jsonb;
begin
  if request is null
    or pg_catalog.jsonb_typeof(request) <> 'object'
    or request - array[
      'contract_version', 'command_id', 'correlation_id',
      'idempotency_key', 'expected_version',
      'requested_by_auth_subject', 'requested_at', 'reason_code',
      'reason_note', 'payload'
    ] <> '{}'::jsonb
    or not (request ?& array[
      'contract_version', 'command_id', 'correlation_id',
      'idempotency_key', 'expected_version',
      'requested_by_auth_subject', 'requested_at', 'reason_code',
      'reason_note', 'payload'
    ])
    or request ->> 'contract_version' is distinct from 'RMVP-02A.v2'
    or request ->> 'reason_code' is distinct from (
      case command_name
        when 'save_recipe' then 'RECIPE_SAVED'
        else 'RECIPE_PUT_INTO_USE'
      end
    )
    or request -> 'reason_note' <> 'null'::jsonb
    or atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
    or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
    or atlas_core.pa_05b_safe_uuid(
      request ->> 'requested_by_auth_subject'
    ) is null
    or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
    or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0
    or atlas_core.pa_05b_safe_timestamptz(
      request ->> 'requested_at'
    ) is null
    or nullif(pg_catalog.btrim(request ->> 'idempotency_key'), '') is null
    or pg_catalog.char_length(request ->> 'idempotency_key') > 200
    or pg_catalog.jsonb_typeof(v_payload) is distinct from 'object'
  then
    return atlas_core.uiq03a_error(
      request,
      command_name,
      'VALIDATION_FAILED',
      'Yêu cầu cập nhật công thức chưa hợp lệ.'
    );
  end if;

  if command_name = 'release_recipe' then
    if v_payload - array['recipe_version_id'] <> '{}'::jsonb
      or atlas_core.pa_05b_safe_uuid(
        v_payload ->> 'recipe_version_id'
      ) is null
    then
      return atlas_core.uiq03a_error(
        request,
        command_name,
        'VALIDATION_FAILED',
        'Chỉ có thể đưa công thức đang được lưu vào sử dụng.'
      );
    end if;
    return null;
  end if;

  if v_payload - array[
      'dish_id', 'school_type_id', 'recipe_version_id',
      'basis_portions', 'lines'
    ] <> '{}'::jsonb
    or not (v_payload ?& array[
      'dish_id', 'school_type_id', 'recipe_version_id',
      'basis_portions', 'lines'
    ])
    or atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id') is null
    or (
      v_payload -> 'school_type_id' <> 'null'::jsonb
      and atlas_core.pa_05b_safe_uuid(
        v_payload ->> 'school_type_id'
      ) is null
    )
    or (
      v_payload -> 'recipe_version_id' <> 'null'::jsonb
      and atlas_core.pa_05b_safe_uuid(
        v_payload ->> 'recipe_version_id'
      ) is null
    )
    or atlas_core.pa_05b_safe_bigint(
      v_payload ->> 'basis_portions'
    ) is null
    or atlas_core.pa_05b_safe_bigint(
      v_payload ->> 'basis_portions'
    ) <= 0
    or atlas_core.pa_05b_safe_bigint(
      v_payload ->> 'basis_portions'
    ) > 2147483647
    or pg_catalog.jsonb_typeof(v_payload -> 'lines') is distinct from 'array'
    or pg_catalog.jsonb_array_length(v_payload -> 'lines') > 500
    or (
      select count(*) <> count(distinct value ->> 'recipe_line_id')
      from pg_catalog.jsonb_array_elements(v_payload -> 'lines')
    )
    or (
      select count(*) <> count(distinct value ->> 'ingredient_id')
      from pg_catalog.jsonb_array_elements(v_payload -> 'lines')
    )
  then
    return atlas_core.uiq03a_error(
      request,
      command_name,
      'VALIDATION_FAILED',
      'Món ăn, phạm vi áp dụng, định lượng và nguyên liệu chưa hợp lệ.'
    );
  end if;

  for v_line in
    select value from pg_catalog.jsonb_array_elements(v_payload -> 'lines')
  loop
    if pg_catalog.jsonb_typeof(v_line) <> 'object'
      or v_line - array[
        'recipe_line_id', 'ingredient_id', 'quantity_per_basis',
        'unit_id', 'operational_note'
      ] <> '{}'::jsonb
      or not (v_line ?& array[
        'recipe_line_id', 'ingredient_id', 'quantity_per_basis',
        'unit_id', 'operational_note'
      ])
      or atlas_core.pa_05b_safe_uuid(
        v_line ->> 'recipe_line_id'
      ) is null
      or atlas_core.pa_05b_safe_uuid(v_line ->> 'ingredient_id') is null
      or atlas_core.pa_05b_safe_uuid(v_line ->> 'unit_id') is null
      or atlas_core.pa_05b_safe_numeric(
        v_line ->> 'quantity_per_basis'
      ) is null
      or atlas_core.pa_05b_safe_numeric(
        v_line ->> 'quantity_per_basis'
      ) <= 0
      or (
        v_line -> 'operational_note' <> 'null'::jsonb
        and pg_catalog.char_length(v_line ->> 'operational_note') > 1000
      )
    then
      return atlas_core.uiq03a_error(
        request,
        command_name,
        'VALIDATION_FAILED',
        'Có nguyên liệu, đơn vị hoặc định lượng chưa hợp lệ.'
      );
    end if;
  end loop;
  return null;
end;
$$;

create function atlas_core.uiq03a_actor_has_capability(
  p_actor_id uuid,
  p_capability_code text
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_core.actor_role_memberships membership
    join atlas_core.roles role_record
      on role_record.role_id = membership.role_id
    join atlas_core.role_capabilities role_capability
      on role_capability.role_id = role_record.role_id
    join atlas_core.capabilities capability
      on capability.capability_id = role_capability.capability_id
    where membership.actor_id = p_actor_id
      and membership.membership_status = 'ACTIVE'
      and membership.effective_from <= pg_catalog.transaction_timestamp()
      and (
        membership.effective_to is null
        or membership.effective_to > pg_catalog.transaction_timestamp()
      )
      and role_record.role_status = 'ACTIVE'
      and capability.capability_status = 'ACTIVE'
      and capability.capability_code = p_capability_code
  ) and exists (
    select 1
    from atlas_core.actor_scopes scope
    where scope.actor_id = p_actor_id
      and scope.scope_status = 'ACTIVE'
      and scope.scope_kind = 'GLOBAL'
      and scope.effective_from <= pg_catalog.transaction_timestamp()
      and (
        scope.effective_to is null
        or scope.effective_to > pg_catalog.transaction_timestamp()
      )
  );
$$;

create function atlas_core.uiq03a_selection_payload(
  p_actor_id uuid,
  p_dish_id uuid,
  p_school_type_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_dish atlas_admin.dishes%rowtype;
  v_recipe atlas_admin.recipes%rowtype;
  v_version atlas_admin.recipe_versions%rowtype;
  v_current_release_id uuid;
  v_save_code text;
  v_release_code text;
  v_save_message text;
  v_release_message text;
  v_composition jsonb := '[]'::jsonb;
  v_release_ready boolean := false;
  v_used_operationally boolean := false;
begin
  if p_dish_id is null then
    select dish.* into v_dish
    from atlas_admin.dishes dish
    order by dish.display_order, dish.dish_name, dish.dish_id
    limit 1;
  else
    select dish.* into v_dish
    from atlas_admin.dishes dish
    where dish.dish_id = p_dish_id;
  end if;

  if not found then
    return pg_catalog.jsonb_build_object(
      'dish_id', p_dish_id,
      'school_type_id', p_school_type_id,
      'recipe_id', null,
      'recipe_version_id', null,
      'business_status', 'NEEDS_ATTENTION',
      'locked_for_normal_editing', false,
      'lock_reason', null,
      'basis_portions', 100,
      'composition', '[]'::jsonb,
      'allowed_actions', pg_catalog.jsonb_build_object(
        'save_recipe', false,
        'release_recipe', false
      ),
      'disabled_reason_codes', pg_catalog.jsonb_build_object(
        'save_recipe', 'DISH_NOT_FOUND',
        'release_recipe', 'DISH_NOT_FOUND'
      ),
      'disabled_reasons', pg_catalog.jsonb_build_object(
        'save_recipe', 'Không tìm thấy món ăn đã chọn.',
        'release_recipe', 'Không tìm thấy món ăn đã chọn.'
      )
    );
  end if;

  v_used_operationally :=
    atlas_core.uiq03a_dish_used_operationally(v_dish.dish_id);

  select recipe.* into v_recipe
  from atlas_admin.recipes recipe
  where recipe.dish_id = v_dish.dish_id
    and recipe.school_type_id is not distinct from p_school_type_id
  order by (recipe.recipe_status = 'ACTIVE') desc, recipe.created_at desc
  limit 1;

  if found then
    select version.* into v_version
    from atlas_admin.recipe_versions version
    where version.recipe_id = v_recipe.recipe_id
    order by
      (version.recipe_version_status = 'DRAFT') desc,
      version.version_number desc,
      version.recipe_version_id desc
    limit 1;

    if found then
      v_composition := coalesce(
        atlas_core.rmvp_02a_recipe_version_composition(
          v_version.recipe_version_id
        ),
        '[]'::jsonb
      );
    end if;

    select version.recipe_version_id into v_current_release_id
    from atlas_admin.recipe_versions version
    where version.recipe_id = v_recipe.recipe_id
      and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
    order by version.version_number desc
    limit 1;
  end if;

  if v_version.recipe_version_status = 'DRAFT' then
    v_release_ready := (
      not v_dish.requires_need_generation
      or exists (
        select 1
        from pg_catalog.jsonb_array_elements(v_composition) item
        where item ->> 'line_disposition' = 'PRESENT'
      )
    ) and not exists (
      select 1
      from pg_catalog.jsonb_array_elements(v_composition) item
      left join atlas_admin.ingredients ingredient
        on ingredient.ingredient_id = atlas_core.pa_05b_safe_uuid(
          item ->> 'ingredient_id'
        )
      left join atlas_admin.units unit
        on unit.unit_id = atlas_core.pa_05b_safe_uuid(item ->> 'unit_id')
      where item ->> 'line_disposition' = 'PRESENT'
        and (
          ingredient.ingredient_id is null
          or ingredient.ingredient_status <> 'ACTIVE'
          or unit.unit_id is null
          or unit.unit_status <> 'ACTIVE'
          or atlas_core.pa_05b_safe_numeric(
            item ->> 'quantity_per_basis'
          ) <= 0
        )
    );
  elsif v_version.recipe_version_status = 'VALIDATED' then
    v_release_ready := true;
  end if;

  v_save_code := case
    when v_used_operationally then 'SAVE_OPERATIONALLY_LOCKED'
    when v_dish.dish_status = 'INACTIVE' then 'SAVE_DISH_INACTIVE'
    when p_school_type_id is not null and not exists (
      select 1 from atlas_admin.school_types school_type
      where school_type.school_type_id = p_school_type_id
        and school_type.school_type_status = 'ACTIVE'
    ) then 'SAVE_SCOPE_UNAVAILABLE'
    when v_recipe.recipe_id is not null
      and v_recipe.recipe_status <> 'ACTIVE' then 'SAVE_RECIPE_INACTIVE'
    when not atlas_core.uiq03a_actor_has_capability(
      p_actor_id, 'master_data.recipes.write'
    ) then 'SAVE_CAPABILITY_REQUIRED'
    else null
  end;

  v_release_code := case
    when v_version.recipe_version_id is null then 'RELEASE_SAVE_REQUIRED'
    when v_dish.dish_status <> 'ACTIVE'
      or v_recipe.recipe_status <> 'ACTIVE' then 'RELEASE_SCOPE_INACTIVE'
    when v_version.recipe_version_status = 'RELEASED_FOR_PLANNING'
      then 'RELEASE_ALREADY_IN_USE'
    when v_version.recipe_version_status not in ('DRAFT', 'VALIDATED')
      then 'RELEASE_SAVE_REQUIRED'
    when not atlas_core.uiq03a_actor_has_capability(
      p_actor_id, 'master_data.recipes.release'
    ) then 'RELEASE_CAPABILITY_REQUIRED'
    when not v_release_ready then 'RELEASE_COMPOSITION_INCOMPLETE'
    else null
  end;

  v_save_message := case v_save_code
    when 'SAVE_OPERATIONALLY_LOCKED'
      then 'Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.'
    when 'SAVE_DISH_INACTIVE'
      then 'Món ăn đã ngừng dùng nên không thể lưu công thức mới.'
    when 'SAVE_SCOPE_UNAVAILABLE'
      then 'Phạm vi áp dụng đã ngừng dùng.'
    when 'SAVE_RECIPE_INACTIVE'
      then 'Công thức ở phạm vi này đã ngừng dùng.'
    when 'SAVE_CAPABILITY_REQUIRED'
      then 'Bạn chưa có quyền lưu công thức.'
    else null
  end;

  v_release_message := case v_release_code
    when 'RELEASE_SAVE_REQUIRED'
      then 'Hãy lưu công thức trước khi xác nhận sẵn sàng cho Lập nhu cầu.'
    when 'RELEASE_SCOPE_INACTIVE'
      then 'Món ăn hoặc phạm vi công thức chưa hoạt động.'
    when 'RELEASE_ALREADY_IN_USE'
      then 'Công thức đã sẵn sàng cho Lập nhu cầu.'
    when 'RELEASE_CAPABILITY_REQUIRED'
      then 'Bạn chưa có quyền đưa công thức vào sử dụng.'
    when 'RELEASE_COMPOSITION_INCOMPLETE'
      then 'Công thức còn nguyên liệu, đơn vị hoặc định lượng cần xử lý.'
    else null
  end;

  return pg_catalog.jsonb_build_object(
    'dish_id', v_dish.dish_id,
    'school_type_id', p_school_type_id,
    'recipe_id', v_recipe.recipe_id,
    'recipe_version_id', v_version.recipe_version_id,
    'expected_version', coalesce(v_version.version, v_dish.version),
    'in_use_recipe_version_id', v_current_release_id,
    'locked_for_normal_editing', v_used_operationally,
    'lock_reason', case when v_used_operationally then
      'Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.'
      else null end,
    'business_status', case
      when v_version.recipe_version_id is null then 'NOT_SAVED'
      when v_used_operationally then 'LOCKED'
      when v_version.recipe_version_status = 'RELEASED_FOR_PLANNING'
        then 'AVAILABLE'
      when v_version.recipe_version_status = 'LOCKED' then 'NEEDS_ATTENTION'
      else 'SAVED'
    end,
    'basis_portions', coalesce(v_version.basis_portions, 100),
    'composition', v_composition,
    'allowed_actions', pg_catalog.jsonb_build_object(
      'save_recipe', v_save_code is null,
      'release_recipe', v_release_code is null
    ),
    'disabled_reason_codes', pg_catalog.jsonb_build_object(
      'save_recipe', v_save_code,
      'release_recipe', v_release_code
    ),
    'disabled_reasons', pg_catalog.jsonb_build_object(
      'save_recipe', v_save_message,
      'release_recipe', v_release_message
    )
  );
end;
$$;

create function atlas_core.uiq03a_workbench_payload(
  p_actor_id uuid,
  p_dish_id uuid,
  p_school_type_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select atlas_core.rmvp_02a_recipe_workbench_payload()
    || pg_catalog.jsonb_build_object(
      'selected_recipe', atlas_core.uiq03a_selection_payload(
        p_actor_id, p_dish_id, p_school_type_id
      )
    );
$$;

create function atlas_core.uiq03a_prepare_command(
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
  v_error := atlas_core.uiq03a_validate_command(request, command_name);
  if v_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_error
    );
  end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request, capability_code, command_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_context -> 'error'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, command_name, 'ADMIN', aggregate_scope
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_begin -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY',
    'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

create function atlas_core.uiq03a_finish_success(
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
  v_events jsonb;
  v_response jsonb;
begin
  v_events := atlas_core.rmvp_01_record_change(
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
      'aggregate_version', p_version_after
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'audit_event_id'
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

create function atlas_api.save_recipe(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'save_recipe';
  v_payload jsonb := request -> 'payload';
  v_dish_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');
  v_school_type_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'school_type_id'
  );
  v_selected_version_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'recipe_version_id'
  );
  v_basis integer := atlas_core.pa_05b_safe_bigint(
    v_payload ->> 'basis_portions'
  )::integer;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_dish atlas_admin.dishes%rowtype;
  v_recipe atlas_admin.recipes%rowtype;
  v_current atlas_admin.recipe_versions%rowtype;
  v_target atlas_admin.recipe_versions%rowtype;
  v_recipe_id uuid;
  v_target_id uuid;
  v_predecessor_id uuid;
  v_next_number integer;
  v_composition jsonb;
  v_before bigint;
  v_after bigint;
begin
  v_prepare := atlas_core.uiq03a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'dish-recipe:' || coalesce(v_dish_id::text, 'invalid') || ':'
      || coalesce(v_school_type_id::text, 'general')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_dish_id::text, 17403)
  );
  select dish.* into v_dish
  from atlas_admin.dishes dish
  where dish.dish_id = v_dish_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'NOT_FOUND', 'Không tìm thấy món ăn đã chọn.'
      ),
      false
    );
  end if;
  if v_dish.dish_status = 'INACTIVE' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'INVARIANT_VIOLATION',
        'Món ăn đã ngừng dùng nên không thể lưu công thức mới.'
      ),
      false
    );
  end if;
  if atlas_core.uiq03a_dish_used_operationally(v_dish_id) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'INVARIANT_VIOLATION',
        'Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.'
      ),
      false
    );
  end if;
  if v_school_type_id is not null and not exists (
    select 1 from atlas_admin.school_types school_type
    where school_type.school_type_id = v_school_type_id
      and school_type.school_type_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'VALIDATION_FAILED',
        'Phạm vi áp dụng đã ngừng dùng hoặc không tồn tại.'
      ),
      false
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_payload -> 'lines') item
    left join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = atlas_core.pa_05b_safe_uuid(
        item ->> 'ingredient_id'
      )
    left join atlas_admin.units unit
      on unit.unit_id = atlas_core.pa_05b_safe_uuid(item ->> 'unit_id')
    where ingredient.ingredient_id is null
      or ingredient.ingredient_status <> 'ACTIVE'
      or unit.unit_id is null
      or unit.unit_status <> 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'VALIDATION_FAILED',
        'Có nguyên liệu hoặc đơn vị đã ngừng dùng.'
      ),
      false
    );
  end if;

  select recipe.* into v_recipe
  from atlas_admin.recipes recipe
  where recipe.dish_id = v_dish_id
    and recipe.school_type_id is not distinct from v_school_type_id
  order by (recipe.recipe_status = 'ACTIVE') desc, recipe.created_at desc
  limit 1
  for update;

  if found then
    if v_recipe.recipe_status <> 'ACTIVE' then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.uiq03a_error(
          request, v_name, 'INVARIANT_VIOLATION',
          'Công thức ở phạm vi này đã ngừng dùng.'
        ),
        false
      );
    end if;
    v_recipe_id := v_recipe.recipe_id;
    select version.* into v_current
    from atlas_admin.recipe_versions version
    where version.recipe_id = v_recipe_id
    order by
      (version.recipe_version_status = 'DRAFT') desc,
      version.version_number desc,
      version.recipe_version_id desc
    limit 1
    for update;
  else
    if v_selected_version_id is not null
      or v_dish.version <> atlas_core.pa_05b_safe_bigint(
        request ->> 'expected_version'
      )
    then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.uiq03a_error(
          request, v_name, 'STALE_VERSION',
          'Dữ liệu món ăn đã thay đổi. Hãy tải lại trước khi lưu.',
          false, v_dish.version
        ),
        false
      );
    end if;
  end if;

  if v_current.recipe_version_id is not null and (
    v_selected_version_id is distinct from v_current.recipe_version_id
    or v_current.version <> atlas_core.pa_05b_safe_bigint(
      request ->> 'expected_version'
    )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'STALE_VERSION',
        'Công thức đã thay đổi. Hãy tải lại trước khi lưu.',
        false, v_current.version
      ),
      false
    );
  end if;

  v_predecessor_id := case
    when v_current.recipe_version_status = 'DRAFT'
      then v_current.predecessor_recipe_version_id
    else v_current.recipe_version_id
  end;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_payload -> 'lines') item
    join atlas_admin.recipe_lines line
      on line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
        item ->> 'recipe_line_id'
      )
    where v_recipe_id is null or line.recipe_id <> v_recipe_id
  ) or exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_payload -> 'lines') item
    join atlas_admin.recipe_lines line
      on line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
        item ->> 'recipe_line_id'
      )
    where v_predecessor_id is not null
      and not exists (
        select 1
        from atlas_admin.recipe_line_revisions revision
        where revision.recipe_version_id = v_predecessor_id
          and revision.recipe_line_id = line.recipe_line_id
      )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'INVARIANT_VIOLATION',
        'Một dòng công thức không thuộc đúng lịch sử đang chỉnh sửa.'
      ),
      false
    );
  end if;

  if v_recipe_id is null then
    insert into atlas_admin.recipes (
      dish_id, school_type_id, recipe_status
    ) values (
      v_dish_id, v_school_type_id, 'ACTIVE'
    ) returning recipe_id into v_recipe_id;
  end if;

  if v_current.recipe_version_status = 'DRAFT' then
    v_target_id := v_current.recipe_version_id;
    v_before := v_current.version;
  else
    v_next_number := coalesce(v_current.version_number, 0) + 1;
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
      v_recipe_id,
      v_next_number,
      v_predecessor_id,
      v_basis,
      'DRAFT',
      v_actor_id,
      '[]'::jsonb,
      pg_catalog.jsonb_build_object(
        'source_kind', 'UIQ03A_SAVE',
        'predecessor_recipe_version_id', v_predecessor_id
      )
    ) returning * into v_target;
    v_target_id := v_target.recipe_version_id;
    v_before := null;
  end if;

  select coalesce(pg_catalog.jsonb_agg(row_item order by ordinal), '[]'::jsonb)
  into v_composition
  from (
    select
      source.ordinal,
      pg_catalog.jsonb_build_object(
        'recipe_line_id', atlas_core.pa_05b_safe_uuid(
          source.item ->> 'recipe_line_id'
        ),
        'predecessor_recipe_line_revision_id', predecessor.recipe_line_revision_id,
        'ingredient_id', atlas_core.pa_05b_safe_uuid(
          source.item ->> 'ingredient_id'
        ),
        'quantity_per_basis', atlas_core.pa_05b_safe_numeric(
          source.item ->> 'quantity_per_basis'
        ),
        'unit_id', atlas_core.pa_05b_safe_uuid(source.item ->> 'unit_id'),
        'line_disposition', 'PRESENT',
        'operational_note', nullif(
          pg_catalog.btrim(source.item ->> 'operational_note'), ''
        ),
        'line_code', line.line_code
      ) as row_item
    from pg_catalog.jsonb_array_elements(v_payload -> 'lines')
      with ordinality source(item, ordinal)
    left join atlas_admin.recipe_line_revisions predecessor
      on predecessor.recipe_version_id = v_predecessor_id
      and predecessor.recipe_line_id = atlas_core.pa_05b_safe_uuid(
        source.item ->> 'recipe_line_id'
      )
    left join atlas_admin.recipe_lines line
      on line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
        source.item ->> 'recipe_line_id'
      )
    union all
    select
      1000000 + predecessor.line_revision_number,
      pg_catalog.jsonb_build_object(
        'recipe_line_id', predecessor.recipe_line_id,
        'predecessor_recipe_line_revision_id',
          predecessor.recipe_line_revision_id,
        'ingredient_id', predecessor.ingredient_id,
        'quantity_per_basis', 0,
        'unit_id', predecessor.unit_id,
        'line_disposition', 'REMOVED',
        'operational_note', predecessor.operational_note,
        'line_code', line.line_code
      )
    from atlas_admin.recipe_line_revisions predecessor
    join atlas_admin.recipe_lines line
      on line.recipe_line_id = predecessor.recipe_line_id
    where predecessor.recipe_version_id = v_predecessor_id
      and predecessor.line_disposition = 'PRESENT'
      and not exists (
        select 1
        from pg_catalog.jsonb_array_elements(v_payload -> 'lines') item
        where atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id')
          = predecessor.recipe_line_id
      )
  ) composition_rows;

  insert into atlas_admin.recipe_lines (
    recipe_line_id, recipe_id, line_code
  )
  select
    atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id'),
    v_recipe_id,
    null
  from pg_catalog.jsonb_array_elements(v_composition) item
  where not exists (
    select 1 from atlas_admin.recipe_lines line
    where line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
      item ->> 'recipe_line_id'
    )
  );

  update atlas_admin.recipe_versions
  set basis_portions = v_basis,
      draft_composition = v_composition,
      source_evidence = source_evidence || pg_catalog.jsonb_build_object(
        'last_saved_via', 'RMVP-02A.v2'
      ),
      version = version + 1
  where recipe_version_id = v_target_id
  returning version into v_after;

  insert into atlas_admin.recipe_line_revisions (
    recipe_id,
    recipe_version_id,
    recipe_line_id,
    line_revision_number,
    predecessor_recipe_line_revision_id,
    ingredient_id,
    quantity_per_basis,
    unit_id,
    line_disposition,
    operational_note,
    created_by_actor_id
  )
  select
    v_recipe_id,
    v_target_id,
    atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id'),
    coalesce(predecessor.line_revision_number + 1, 1),
    predecessor.recipe_line_revision_id,
    atlas_core.pa_05b_safe_uuid(item ->> 'ingredient_id'),
    atlas_core.pa_05b_safe_numeric(item ->> 'quantity_per_basis'),
    atlas_core.pa_05b_safe_uuid(item ->> 'unit_id'),
    item ->> 'line_disposition',
    nullif(item ->> 'operational_note', ''),
    v_actor_id
  from pg_catalog.jsonb_array_elements(v_composition) item
  left join atlas_admin.recipe_line_revisions predecessor
    on predecessor.recipe_line_revision_id =
      atlas_core.pa_05b_safe_uuid(
        item ->> 'predecessor_recipe_line_revision_id'
      );

  update atlas_admin.recipe_versions
  set recipe_version_status = 'VALIDATED',
      validated_by_actor_id = v_actor_id,
      validated_at = pg_catalog.transaction_timestamp(),
      version = version + 1
  where recipe_version_id = v_target_id;
  set constraints atlas_admin.recipe_versions_integrity_guard immediate;
  set constraints atlas_admin.recipe_versions_integrity_guard deferred;

  update atlas_admin.recipe_versions
  set recipe_version_status = 'RELEASED_FOR_PLANNING',
      released_by_actor_id = v_actor_id,
      released_at = pg_catalog.transaction_timestamp(),
      version = version + 1
  where recipe_version_id = v_target_id
  returning version into v_after;
  set constraints atlas_admin.recipe_versions_integrity_guard immediate;
  set constraints atlas_admin.recipe_versions_integrity_guard deferred;

  return atlas_core.uiq03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeSaved',
    v_target_id,
    v_before,
    v_after,
    case when v_before is null then null else pg_catalog.jsonb_build_object(
      'recipe_version_status', 'DRAFT'
    ) end,
    pg_catalog.jsonb_build_object(
      'recipe_version_status', 'RELEASED_FOR_PLANNING',
      'basis_portions', v_basis,
      'present_line_count', pg_catalog.jsonb_array_length(
        v_payload -> 'lines'
      ),
      'released_for_planning', true,
      'operationally_used', false
    ),
    'Đã tạo và lưu công thức. Công thức sẵn sàng cho Lập nhu cầu và vẫn có thể chỉnh sửa cho đến khi được sử dụng.',
    v_dish_id,
    v_school_type_id
  );
exception
  when unique_violation then
    return atlas_core.uiq03a_error(
      request, v_name, 'CONFLICT',
      'Công thức đã được cập nhật đồng thời. Hãy tải lại.'
    );
  when serialization_failure or deadlock_detected then
    return atlas_core.uiq03a_error(
      request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
      'Công thức chưa thể được khóa an toàn. Hãy tải lại trước khi thử lại.',
      true
    );
  when others then
    return atlas_core.uiq03a_error(
      request, v_name, 'INTERNAL_COMMAND_FAILURE',
      'Không thể lưu công thức một cách an toàn.'
    );
end;
$$;

create function atlas_api.release_recipe(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'release_recipe';
  v_recipe_version_id uuid := atlas_core.pa_05b_safe_uuid(
    request #>> '{payload,recipe_version_id}'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_version atlas_admin.recipe_versions%rowtype;
  v_recipe atlas_admin.recipes%rowtype;
  v_dish atlas_admin.dishes%rowtype;
  v_line_count integer;
  v_before bigint;
  v_after bigint;
begin
  v_prepare := atlas_core.uiq03a_prepare_command(
    request,
    v_name,
    'master_data.recipes.release',
    'recipe-version:' || coalesce(v_recipe_version_id::text, 'invalid')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select version.* into v_version
  from atlas_admin.recipe_versions version
  where version.recipe_version_id = v_recipe_version_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'NOT_FOUND', 'Không tìm thấy công thức đang lưu.'
      ),
      false
    );
  end if;
  v_before := v_version.version;
  if v_version.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) or exists (
    select 1 from atlas_admin.recipe_versions newer
    where newer.recipe_id = v_version.recipe_id
      and newer.version_number > v_version.version_number
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'STALE_VERSION',
        'Công thức đã thay đổi. Hãy tải lại trước khi xác nhận cho Lập nhu cầu.',
        false, v_version.version
      ),
      false
    );
  end if;
  if v_version.recipe_version_status not in ('DRAFT', 'VALIDATED') then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'INVARIANT_VIOLATION',
        case
          when v_version.recipe_version_status = 'RELEASED_FOR_PLANNING'
            then 'Công thức đã sẵn sàng cho Lập nhu cầu.'
          else 'Hãy lưu công thức hiện tại trước khi xác nhận cho Lập nhu cầu.'
        end
      ),
      false
    );
  end if;

  select recipe.* into v_recipe
  from atlas_admin.recipes recipe
  where recipe.recipe_id = v_version.recipe_id
  for update;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_recipe.dish_id::text, 17403)
  );
  select dish.* into v_dish
  from atlas_admin.dishes dish
  where dish.dish_id = v_recipe.dish_id
  for update;
  if v_recipe.recipe_status <> 'ACTIVE'
    or v_dish.dish_status <> 'ACTIVE'
  then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'INVARIANT_VIOLATION',
        'Món ăn và phạm vi công thức phải đang hoạt động.'
      ),
      false
    );
  end if;
  if atlas_core.uiq03a_dish_used_operationally(v_dish.dish_id) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request, v_name, 'INVARIANT_VIOLATION',
        'Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.'
      ),
      false
    );
  end if;

  if v_version.recipe_version_status = 'DRAFT' then
    v_line_count := (
      select count(*)::integer
      from pg_catalog.jsonb_array_elements(v_version.draft_composition) item
      where item ->> 'line_disposition' = 'PRESENT'
    );
    if v_dish.requires_need_generation and v_line_count = 0 then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.uiq03a_error(
          request, v_name, 'VALIDATION_FAILED',
          'Hãy thêm ít nhất một nguyên liệu trước khi đưa công thức vào sử dụng.'
        ),
        false
      );
    end if;
    if exists (
      select 1
      from pg_catalog.jsonb_array_elements(v_version.draft_composition) item
      left join atlas_admin.ingredients ingredient
        on ingredient.ingredient_id = atlas_core.pa_05b_safe_uuid(
          item ->> 'ingredient_id'
        )
      left join atlas_admin.units unit
        on unit.unit_id = atlas_core.pa_05b_safe_uuid(item ->> 'unit_id')
      where item ->> 'line_disposition' = 'PRESENT'
        and (
          ingredient.ingredient_id is null
          or ingredient.ingredient_status <> 'ACTIVE'
          or unit.unit_id is null
          or unit.unit_status <> 'ACTIVE'
          or atlas_core.pa_05b_safe_numeric(
            item ->> 'quantity_per_basis'
          ) <= 0
        )
    ) then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.uiq03a_error(
          request, v_name, 'VALIDATION_FAILED',
          'Công thức còn nguyên liệu, đơn vị hoặc định lượng cần xử lý.'
        ),
        false
      );
    end if;
    if v_version.predecessor_recipe_version_id is not null and exists (
      select 1
      from atlas_admin.recipe_line_revisions predecessor
      where predecessor.recipe_version_id =
        v_version.predecessor_recipe_version_id
        and predecessor.line_disposition = 'PRESENT'
        and not exists (
          select 1
          from pg_catalog.jsonb_array_elements(
            v_version.draft_composition
          ) item
          where atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id')
            = predecessor.recipe_line_id
            and atlas_core.pa_05b_safe_uuid(
              item ->> 'predecessor_recipe_line_revision_id'
            ) = predecessor.recipe_line_revision_id
        )
    ) then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.uiq03a_error(
          request, v_name, 'INVARIANT_VIOLATION',
          'Lịch sử nguyên liệu chưa đầy đủ. Hãy tải lại công thức.'
        ),
        false
      );
    end if;

    insert into atlas_admin.recipe_line_revisions (
      recipe_id,
      recipe_version_id,
      recipe_line_id,
      line_revision_number,
      predecessor_recipe_line_revision_id,
      ingredient_id,
      quantity_per_basis,
      unit_id,
      line_disposition,
      operational_note,
      created_by_actor_id
    )
    select
      v_version.recipe_id,
      v_version.recipe_version_id,
      atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id'),
      coalesce(predecessor.line_revision_number + 1, 1),
      predecessor.recipe_line_revision_id,
      atlas_core.pa_05b_safe_uuid(item ->> 'ingredient_id'),
      atlas_core.pa_05b_safe_numeric(item ->> 'quantity_per_basis'),
      atlas_core.pa_05b_safe_uuid(item ->> 'unit_id'),
      item ->> 'line_disposition',
      nullif(item ->> 'operational_note', ''),
      v_actor_id
    from pg_catalog.jsonb_array_elements(v_version.draft_composition) item
    left join atlas_admin.recipe_line_revisions predecessor
      on predecessor.recipe_line_revision_id =
        atlas_core.pa_05b_safe_uuid(
          item ->> 'predecessor_recipe_line_revision_id'
        );

    update atlas_admin.recipe_versions
    set recipe_version_status = 'VALIDATED',
        validated_by_actor_id = v_actor_id,
        validated_at = pg_catalog.transaction_timestamp(),
        version = version + 1
    where recipe_version_id = v_recipe_version_id;
    set constraints atlas_admin.recipe_versions_integrity_guard immediate;
    set constraints atlas_admin.recipe_versions_integrity_guard deferred;

    if v_version.source_evidence ->> 'source_kind' = 'WORKBOOK_IMPORT' then
      insert into atlas_legacy.master_data_mappings (
        import_batch_id,
        source_system,
        object_type,
        legacy_id,
        recipe_line_revision_id
      )
      select
        atlas_core.pa_05b_safe_uuid(
          v_version.source_evidence ->> 'import_batch_id'
        ),
        v_version.source_evidence ->> 'source_system',
        'RECIPE_LINE_REVISION',
        item ->> 'legacy_line_id',
        revision.recipe_line_revision_id
      from pg_catalog.jsonb_array_elements(v_version.draft_composition) item
      join atlas_admin.recipe_line_revisions revision
        on revision.recipe_version_id = v_version.recipe_version_id
        and revision.recipe_line_id = atlas_core.pa_05b_safe_uuid(
          item ->> 'recipe_line_id'
        )
      where nullif(item ->> 'legacy_line_id', '') is not null
      on conflict (source_system, object_type, legacy_id) do update set
        import_batch_id = excluded.import_batch_id,
        recipe_line_revision_id = excluded.recipe_line_revision_id,
        updated_at = pg_catalog.transaction_timestamp();
    end if;
  end if;

  update atlas_admin.recipe_versions
  set recipe_version_status = 'RELEASED_FOR_PLANNING',
      released_by_actor_id = v_actor_id,
      released_at = pg_catalog.transaction_timestamp(),
      version = version + 1
  where recipe_version_id = v_recipe_version_id
  returning version into v_after;
  set constraints atlas_admin.recipe_versions_integrity_guard immediate;
  set constraints atlas_admin.recipe_versions_integrity_guard deferred;

  return atlas_core.uiq03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipePutIntoUse',
    v_recipe_version_id,
    v_before,
    v_after,
    pg_catalog.jsonb_build_object(
      'recipe_version_status', v_version.recipe_version_status
    ),
    pg_catalog.jsonb_build_object(
      'recipe_version_status', 'RELEASED_FOR_PLANNING',
      'validation_materialized', true,
      'effect', 'FUTURE_PLANNING_REFERENCE_ONLY',
      'historical_planning_recalculated', false
    ),
    'Đã xác nhận công thức sẵn sàng cho các lần Lập nhu cầu sau.',
    v_dish.dish_id,
    v_recipe.school_type_id
  );
exception
  when unique_violation then
    return atlas_core.uiq03a_error(
      request, v_name, 'CONFLICT',
      'Một công thức khác đã được xác nhận cho Lập nhu cầu đồng thời. Hãy tải lại.'
    );
  when serialization_failure or deadlock_detected then
    return atlas_core.uiq03a_error(
      request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
      'Công thức chưa thể được khóa an toàn. Hãy tải lại trước khi thử lại.',
      true
    );
  when others then
    return atlas_core.uiq03a_error(
      request, v_name, 'INTERNAL_COMMAND_FAILURE',
      'Không thể đưa công thức vào sử dụng một cách an toàn.'
    );
end;
$$;

reset role;
grant create on schema atlas_api, atlas_core to atlas_read_runtime;
set role atlas_read_runtime;

create or replace function atlas_api.get_dish_recipe_workbench(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_dish_recipe_workbench';
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_payload jsonb := request -> 'payload';
begin
  if request ->> 'contract_version' = 'RMVP-02A.v1' then
    v_error := atlas_core.rmvp_02a_validate_read_request(request, v_name);
  else
    v_error := atlas_core.uiq03a_validate_read(request, v_name);
  end if;
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request, 'master_data.recipes.read', v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');

  if request ->> 'contract_version' = 'RMVP-02A.v1' then
    return pg_catalog.jsonb_build_object(
      'success', true,
      'contract_version', 'RMVP-02A.v1',
      'correlation_id', request ->> 'correlation_id',
      'workbench', atlas_core.rmvp_02a_recipe_workbench_payload(),
      'safe_operator_message',
        'Authorized Dish, Recipe, and BOM data returned.'
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02A.v2',
    'correlation_id', request ->> 'correlation_id',
    'workbench', atlas_core.uiq03a_workbench_payload(
      v_actor_id,
      atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id'),
      atlas_core.pa_05b_safe_uuid(v_payload ->> 'school_type_id')
    ),
    'safe_operator_message', 'Đã tải công thức và quyền thao tác hiện tại.'
  );
exception when others then
  if request ->> 'contract_version' = 'RMVP-02A.v1' then
    return atlas_core.rmvp_02a_read_error(
      request, v_name, 'INTERNAL_READ_FAILURE',
      'Dish, Recipe, and BOM data could not be returned safely.'
    );
  end if;
  return atlas_core.uiq03a_error(
    request, v_name, 'INTERNAL_READ_FAILURE',
    'Không thể tải công thức một cách an toàn.'
  );
end;
$$;

reset role;

alter function atlas_core.uiq03a_error(
  jsonb, text, text, text, boolean, bigint
) owner to atlas_owner;
alter function atlas_core.uiq03a_validate_read(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.uiq03a_validate_command(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.uiq03a_actor_has_capability(uuid, text)
  owner to atlas_owner;
alter function atlas_core.uiq03a_dish_used_operationally(uuid)
  owner to atlas_read_runtime;
alter function atlas_core.uiq03a_selection_payload(uuid, uuid, uuid)
  owner to atlas_owner;
alter function atlas_core.uiq03a_workbench_payload(uuid, uuid, uuid)
  owner to atlas_owner;
alter function atlas_core.uiq03a_prepare_command(jsonb, text, text, text)
  owner to atlas_owner;
alter function atlas_core.uiq03a_finish_success(
  jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb,
  text, uuid, uuid
) owner to atlas_owner;

alter function atlas_api.get_dish_recipe_workbench(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.save_recipe(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.release_recipe(jsonb)
  owner to atlas_master_data_command_runtime;

revoke create on schema atlas_core, atlas_api
  from atlas_master_data_command_runtime;
revoke create on schema atlas_api, atlas_core from atlas_read_runtime;
revoke select (dish_id)
  on atlas_planning.weekly_menu_approval_snapshot_lines
  from atlas_master_data_command_runtime;
revoke usage on schema atlas_planning
  from atlas_master_data_command_runtime;

grant execute on function
  atlas_core.uiq03a_error(jsonb, text, text, text, boolean, bigint),
  atlas_core.uiq03a_validate_read(jsonb, text),
  atlas_core.uiq03a_actor_has_capability(uuid, text),
  atlas_core.uiq03a_dish_used_operationally(uuid),
  atlas_core.uiq03a_selection_payload(uuid, uuid, uuid),
  atlas_core.uiq03a_workbench_payload(uuid, uuid, uuid)
to atlas_read_runtime;

grant execute on function
  atlas_core.uiq03a_error(jsonb, text, text, text, boolean, bigint),
  atlas_core.uiq03a_validate_command(jsonb, text),
  atlas_core.uiq03a_actor_has_capability(uuid, text),
  atlas_core.uiq03a_dish_used_operationally(uuid),
  atlas_core.uiq03a_selection_payload(uuid, uuid, uuid),
  atlas_core.uiq03a_workbench_payload(uuid, uuid, uuid),
  atlas_core.uiq03a_prepare_command(jsonb, text, text, text),
  atlas_core.uiq03a_finish_success(
    jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb,
    text, uuid, uuid
  )
to atlas_master_data_command_runtime;

revoke execute on function
  atlas_core.uiq03a_error(jsonb, text, text, text, boolean, bigint),
  atlas_core.uiq03a_validate_read(jsonb, text),
  atlas_core.uiq03a_validate_command(jsonb, text),
  atlas_core.uiq03a_actor_has_capability(uuid, text),
  atlas_core.uiq03a_dish_used_operationally(uuid),
  atlas_core.uiq03a_selection_payload(uuid, uuid, uuid),
  atlas_core.uiq03a_workbench_payload(uuid, uuid, uuid),
  atlas_core.uiq03a_prepare_command(jsonb, text, text, text),
  atlas_core.uiq03a_finish_success(
    jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb,
    text, uuid, uuid
  )
from public, anon, authenticated, service_role;

revoke execute on function
  atlas_api.save_recipe(jsonb),
  atlas_api.release_recipe(jsonb)
from public, anon, service_role;
grant execute on function
  atlas_api.save_recipe(jsonb),
  atlas_api.release_recipe(jsonb)
to authenticated;

comment on function atlas_api.get_dish_recipe_workbench(jsonb) is
  'RMVP-02A.v1/v2 authorized Recipe workbench read. V2 adds current-effective context, creation eligibility, and approved-Menu operational lock readback.';
comment on function atlas_api.save_recipe(jsonb) is
  'RMVP-02A.v2 atomic creation Save. Creates or advances the pre-use Recipe, materializes and makes it eligible for Planning, and denies normal editing after the Dish appears in an approved Weekly Menu snapshot.';
comment on function atlas_api.release_recipe(jsonb) is
  'RMVP-02A.v2 compatibility/support release entry point. It is not a normal creation-workbench action; RMVP-02A.v1 APIs remain physically callable.';

revoke atlas_master_data_command_runtime, atlas_read_runtime from postgres;
