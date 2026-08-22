-- Issue #213 root-review correction: preserve the accepted Dish lifecycle
-- activation preconditions before any Recipe business write. The existing
-- partial unique index remains the final concurrent-race guard.

grant atlas_master_data_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_master_data_command_runtime;
set role atlas_master_data_command_runtime;

create or replace function atlas_api.save_recipe(request jsonb)
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
  v_constraint_name text;
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

  if v_dish.dish_status = 'DRAFT' and not exists (
    select 1
    from atlas_admin.dish_types dish_type
    where dish_type.dish_type_id = v_dish.dish_type_id
      and dish_type.dish_type_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request,
        v_name,
        'INVARIANT_VIOLATION',
        'An active database-backed Dish Type is required before activation.'
      ),
      false
    );
  end if;
  if v_dish.dish_status = 'DRAFT' and exists (
    select 1
    from atlas_admin.dishes other_dish
    where other_dish.dish_id <> v_dish_id
      and other_dish.dish_status = 'ACTIVE'
      and pg_catalog.lower(pg_catalog.btrim(other_dish.dish_name))
        = pg_catalog.lower(pg_catalog.btrim(v_dish.dish_name))
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.uiq03a_error(
        request,
        v_name,
        'CONFLICT',
        'An active dish with this normalized name already exists.'
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
    get stacked diagnostics v_constraint_name = constraint_name;
    if v_constraint_name = 'dishes_active_normalized_name_key' then
      return atlas_core.uiq03a_error(
        request,
        v_name,
        'CONFLICT',
        'An active dish with this normalized name already exists.'
      );
    end if;
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

comment on function atlas_api.save_recipe(jsonb) is
  'RMVP-02A.v2 normal Recipe Save. Before Recipe writes, DRAFT Dish activation preserves active Dish Type and normalized active-name lifecycle invariants; the partial unique index remains the final concurrency guard.';


reset role;
revoke create on schema atlas_api from atlas_master_data_command_runtime;
revoke atlas_master_data_command_runtime from postgres;
