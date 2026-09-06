-- RECIPE-SYSTEM-COMMAND-CONTEXT-01
-- Add the explicit Dish + canonical School-Type review context to the
-- existing SYSTEM_DISH Preview/Create/Supersede commands. School-scoped and
-- SYSTEM_INGREDIENT impact-preview behavior remains on the existing resolver.

do $preview_patch$
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
$old$  v_school_id uuid;
  v_dish_id uuid;$old$,
$new$  v_school_id uuid;
  v_school_type_id uuid;
  v_dish_id uuid;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Preview declaration patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_school_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'school_id'
  );
  v_dish_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');$old$,
$new$  v_school_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'school_id'
  );
  v_school_type_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'school_type_id'
  );
  v_dish_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Preview context parse patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  if v_context ? 'error' then return v_context -> 'error'; end if;

  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment($old$,
$new$  if v_context ? 'error' then return v_context -> 'error'; end if;

  if v_proposal ->> 'scope_kind' = 'SYSTEM_DISH' then
    if v_payload ->> 'school_id' is not null
       or v_school_type_id is null
       or v_proposal ->> 'school_id' is not null
       or atlas_core.pa_05b_safe_uuid(
         v_proposal ->> 'dish_id'
       ) is distinct from v_dish_id
       or atlas_core.pa_05b_safe_uuid(
         v_proposal ->> 'school_type_id'
       ) is distinct from v_school_type_id
       or not exists (
         select 1
         from atlas_core.recipe_effective_canonical_school_types() canonical
         where canonical.school_type_id = v_school_type_id
       ) then
      return atlas_core.rmvp_02b_read_error(
        request,
        v_name,
        'VALIDATION_FAILED',
        'SYSTEM_DISH preview requires the same Dish and active canonical School Type as the proposal, without a School.'
      );
    end if;
  elsif v_school_id is null
        or v_payload ->> 'school_type_id' is not null then
    return atlas_core.rmvp_02b_read_error(
      request,
      v_name,
      'VALIDATION_FAILED',
      'This adjustment scope requires the existing School and Dish impact-preview context.'
    );
  end if;

  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment($new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Preview validation patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_before := atlas_core.rmvp_02b_resolve_effective_composition(
    v_as_of_date,
    v_school_id,
    v_dish_id
  );$old$,
$new$  if v_proposal ->> 'scope_kind' = 'SYSTEM_DISH' then
    v_before := atlas_core.recipe_effective_resolve_composition(
      v_as_of_date,
      null,
      v_dish_id,
      v_school_type_id
    );
  else
    v_before := atlas_core.rmvp_02b_resolve_effective_composition(
      v_as_of_date,
      v_school_id,
      v_dish_id
    );
  end if;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Preview before-resolution patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$    v_after := atlas_core.rmvp_02b_resolve_effective_composition(
      v_as_of_date,
      v_school_id,
      v_dish_id,
      v_proposal,
      v_replaced_id
    );$old$,
$new$    if v_proposal ->> 'scope_kind' = 'SYSTEM_DISH' then
      v_after := atlas_core.recipe_effective_resolve_composition(
        v_as_of_date,
        null,
        v_dish_id,
        v_school_type_id,
        v_proposal,
        v_replaced_id
      );
    else
      v_after := atlas_core.rmvp_02b_resolve_effective_composition(
        v_as_of_date,
        v_school_id,
        v_dish_id,
        v_proposal,
        v_replaced_id
      );
    end if;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Preview after-resolution patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$      'school_id', v_school_id,
      'dish_id', v_dish_id,$old$,
$new$      'school_id', v_school_id,
      'school_type_id', v_school_type_id,
      'dish_id', v_dish_id,$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Preview response-context patch did not match';
  end if;

  execute v_patched;
end;
$preview_patch$;

do $create_patch$
declare
  v_original text;
  v_patched text;
begin
  v_original := pg_catalog.pg_get_functiondef(
    'atlas_api.create_recipe_composition_adjustment(jsonb)'
      ::pg_catalog.regprocedure
  );

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_preview_school_id uuid;
  v_preview_dish_id uuid;$old$,
$new$  v_preview_school_id uuid;
  v_preview_school_type_id uuid;
  v_preview_dish_id uuid;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Create declaration patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_after jsonb;
  v_before_target_ingredient text;$old$,
$new$  v_after jsonb;
  v_before jsonb;
  v_before_target_ingredient text;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Create before-state patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_preview_school_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_school_id'
  );
  v_preview_dish_id := atlas_core.pa_05b_safe_uuid($old$,
$new$  v_preview_school_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_school_id'
  );
  v_preview_school_type_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_school_type_id'
  );
  v_preview_dish_id := atlas_core.pa_05b_safe_uuid($new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Create context parse patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  if v_as_of_date is null
     or v_preview_school_id is null
     or v_preview_dish_id is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The command must name the explicit date, School, and Dish used for preview.',
      'ADMIN',
      v_name
    );
  end if;$old$,
$new$  if v_as_of_date is null
     or v_preview_dish_id is null
     or (
       v_scope = 'SYSTEM_DISH'
       and (
         v_payload ->> 'preview_school_id' is not null
         or v_preview_school_type_id is null
       )
     )
     or (
       coalesce(v_scope, '') <> 'SYSTEM_DISH'
       and (
         v_preview_school_id is null
         or v_payload ->> 'preview_school_type_id' is not null
       )
     ) then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The command must name the explicit date, Dish, and exactly one permitted School or School-Type preview context.',
      'ADMIN',
      v_name
    );
  end if;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Create required-context patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment($old$,
$new$  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  if v_scope = 'SYSTEM_DISH'
     and (
       v_payload ->> 'school_id' is not null
       or v_dish_id is distinct from v_preview_dish_id
       or v_school_type_id is distinct from v_preview_school_type_id
       or not exists (
         select 1
         from atlas_core.recipe_effective_canonical_school_types() canonical
         where canonical.school_type_id = v_preview_school_type_id
       )
     ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'SYSTEM_DISH create requires the same Dish and active canonical School Type reviewed without a School.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;

  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment($new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Create exact-context patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_after := atlas_core.rmvp_02b_resolve_effective_composition(
    v_as_of_date,
    v_preview_school_id,
    v_preview_dish_id,
    v_proposal
  );$old$,
$new$  if v_scope = 'SYSTEM_DISH' then
    v_after := atlas_core.recipe_effective_resolve_composition(
      v_as_of_date,
      null,
      v_preview_dish_id,
      v_preview_school_type_id,
      v_proposal
    );
  else
    v_after := atlas_core.rmvp_02b_resolve_effective_composition(
      v_as_of_date,
      v_preview_school_id,
      v_preview_dish_id,
      v_proposal
    );
  end if;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Create after-resolution patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  if v_action = 'REPLACE'
     and (
       v_target_recipe_line_id is not null
       or v_adjustment_line_id is not null
     ) then
    select line ->> 'final_ingredient_id'$old$,
$new$  if v_action = 'REPLACE'
     and (
       v_target_recipe_line_id is not null
       or v_adjustment_line_id is not null
     ) then
    if v_scope = 'SYSTEM_DISH' then
      v_before := atlas_core.recipe_effective_resolve_composition(
        v_as_of_date,
        null,
        v_preview_dish_id,
        v_preview_school_type_id
      );
    else
      v_before := atlas_core.rmvp_02b_resolve_effective_composition(
        v_as_of_date,
        v_preview_school_id,
        v_preview_dish_id
      );
    end if;
    select line ->> 'final_ingredient_id'$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Create self-replacement context patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$    from pg_catalog.jsonb_array_elements(
      (
        atlas_core.rmvp_02b_resolve_effective_composition(
          v_as_of_date,
          v_preview_school_id,
          v_preview_dish_id
        )
      ) -> 'lines'
    ) line$old$,
$new$    from pg_catalog.jsonb_array_elements(v_before -> 'lines') line$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Create self-replacement resolver patch did not match';
  end if;

  execute v_patched;
end;
$create_patch$;

do $supersede_patch$
declare
  v_original text;
  v_patched text;
begin
  v_original := pg_catalog.pg_get_functiondef(
    'atlas_api.supersede_recipe_composition_adjustment(jsonb)'
      ::pg_catalog.regprocedure
  );

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_preview_school_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_school_id'
  );
  v_preview_dish_id uuid := atlas_core.pa_05b_safe_uuid($old$,
$new$  v_preview_school_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_school_id'
  );
  v_preview_school_type_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'preview_school_type_id'
  );
  v_preview_dish_id uuid := atlas_core.pa_05b_safe_uuid($new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Supersede context parse patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_after jsonb;
  v_next_number integer;$old$,
$new$  v_after jsonb;
  v_before jsonb;
  v_next_number integer;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Supersede before-state patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  if v_adjustment_id is null or v_revision_id is null
     or v_predecessor_id is null or v_as_of_date is null
     or v_preview_school_id is null or v_preview_dish_id is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Adjustment, predecessor, successor revision, and preview date are required.',
      'ADMIN',
      v_name
    );
  end if;$old$,
$new$  if v_adjustment_id is null or v_revision_id is null
     or v_predecessor_id is null or v_as_of_date is null
     or v_preview_dish_id is null
     or (v_payload ->> 'preview_school_id' is null) =
       (v_payload ->> 'preview_school_type_id' is null) then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Adjustment, predecessor, successor revision, date, Dish, and exactly one permitted School or School-Type preview context are required.',
      'ADMIN',
      v_name
    );
  end if;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Supersede required-context patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment(
    v_proposal,$old$,
$new$  if v_root.scope_kind = 'SYSTEM_DISH' then
    if v_payload ->> 'preview_school_id' is not null
       or v_preview_school_type_id is null
       or v_root.school_id is not null
       or v_root.dish_id is distinct from v_preview_dish_id
       or v_root.school_type_id is distinct from v_preview_school_type_id
       or not exists (
         select 1
         from atlas_core.recipe_effective_canonical_school_types() canonical
         where canonical.school_type_id = v_preview_school_type_id
       ) then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'VALIDATION_FAILED',
          'SYSTEM_DISH supersede requires the same Dish and active canonical School Type reviewed without a School.',
          'ADMIN',
          v_name
        ),
        false
      );
    end if;
  elsif v_preview_school_id is null
        or v_payload ->> 'preview_school_type_id' is not null then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'This adjustment scope requires the existing School and Dish impact-preview context.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;

  v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment(
    v_proposal,$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Supersede exact-context patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  v_after := atlas_core.rmvp_02b_resolve_effective_composition(
    v_as_of_date,
    v_preview_school_id,
    v_preview_dish_id,
    v_proposal,
    v_adjustment_id
  );$old$,
$new$  if v_root.scope_kind = 'SYSTEM_DISH' then
    v_after := atlas_core.recipe_effective_resolve_composition(
      v_as_of_date,
      null,
      v_preview_dish_id,
      v_preview_school_type_id,
      v_proposal,
      v_adjustment_id
    );
  else
    v_after := atlas_core.rmvp_02b_resolve_effective_composition(
      v_as_of_date,
      v_preview_school_id,
      v_preview_dish_id,
      v_proposal,
      v_adjustment_id
    );
  end if;$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Supersede after-resolution patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$  if v_root.action_kind = 'REPLACE'
     and (
       v_root.target_recipe_line_id is not null
       or v_root.adjustment_line_id is not null
     ) then
    select line ->> 'final_ingredient_id'$old$,
$new$  if v_root.action_kind = 'REPLACE'
     and (
       v_root.target_recipe_line_id is not null
       or v_root.adjustment_line_id is not null
     ) then
    if v_root.scope_kind = 'SYSTEM_DISH' then
      v_before := atlas_core.recipe_effective_resolve_composition(
        v_as_of_date,
        null,
        v_preview_dish_id,
        v_preview_school_type_id,
        null,
        v_adjustment_id
      );
    else
      v_before := atlas_core.rmvp_02b_resolve_effective_composition(
        v_as_of_date,
        v_preview_school_id,
        v_preview_dish_id,
        null,
        v_adjustment_id
      );
    end if;
    select line ->> 'final_ingredient_id'$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Supersede self-replacement context patch did not match';
  end if;
  v_original := v_patched;

  v_patched := pg_catalog.replace(
    v_original,
$old$    from pg_catalog.jsonb_array_elements(
      (
        atlas_core.rmvp_02b_resolve_effective_composition(
          v_as_of_date,
          v_preview_school_id,
          v_preview_dish_id,
          null,
          v_adjustment_id
        )
      ) -> 'lines'
    ) line$old$,
$new$    from pg_catalog.jsonb_array_elements(v_before -> 'lines') line$new$
  );
  if v_patched = v_original then
    raise exception 'SYSTEM_DISH Supersede self-replacement resolver patch did not match';
  end if;

  execute v_patched;
end;
$supersede_patch$;

comment on function atlas_api.preview_recipe_composition_adjustment(jsonb) is
  'RMVP-02B.v1 authoritative no-write preview. SYSTEM_DISH uses Dish plus canonical School Type; other scopes retain School impact context.';
comment on function atlas_api.create_recipe_composition_adjustment(jsonb) is
  'RMVP-02B.v1 create command with reviewed School context or explicit SYSTEM_DISH Dish plus canonical School-Type context.';
comment on function atlas_api.supersede_recipe_composition_adjustment(jsonb) is
  'RMVP-02B.v1 immutable successor command with reviewed School context or explicit SYSTEM_DISH Dish plus canonical School-Type context.';
