-- RMVP-02A: connected Dish, scoped Recipe, immutable BOM lifecycle, copy,
-- workbook import, and typed reconciliation.
--
-- Draft composition is staged on the existing RecipeVersion row. Validation
-- materializes it exactly once into stable RecipeLine identities and immutable
-- RecipeLineRevision facts. No competing Recipe/BOM relation is introduced.

set role atlas_owner;

alter table atlas_admin.recipe_versions
  add column version bigint not null default 1,
  add column draft_composition jsonb not null default '[]'::jsonb,
  add column source_evidence jsonb not null default '{}'::jsonb,
  add constraint recipe_versions_version_check check (version > 0),
  add constraint recipe_versions_draft_composition_check check (
    pg_catalog.jsonb_typeof(draft_composition) = 'array'
  ),
  add constraint recipe_versions_source_evidence_check check (
    pg_catalog.jsonb_typeof(source_evidence) = 'object'
  );

comment on column atlas_admin.recipe_versions.draft_composition is
  'RMVP-02A mutable DRAFT-only staging manifest. Validation materializes it exactly once into immutable RecipeLineRevision facts.';
comment on column atlas_admin.recipe_versions.source_evidence is
  'Immutable creation evidence for manual successor, controlled copy, or reviewed workbook import.';
comment on column atlas_admin.recipe_versions.version is
  'Optimistic-concurrency version for draft composition and lifecycle commands.';

alter table atlas_legacy.master_data_mappings
  drop constraint master_data_mappings_object_type_check,
  drop constraint master_data_mappings_typed_target_check,
  add column dish_id uuid,
  add column recipe_id uuid,
  add column recipe_version_id uuid,
  add column recipe_line_id uuid,
  add column recipe_line_revision_id uuid,
  add constraint master_data_mappings_dish_fkey foreign key (dish_id)
    references atlas_admin.dishes (dish_id) on delete restrict,
  add constraint master_data_mappings_recipe_fkey foreign key (recipe_id)
    references atlas_admin.recipes (recipe_id) on delete restrict,
  add constraint master_data_mappings_recipe_version_fkey foreign key (
    recipe_version_id
  ) references atlas_admin.recipe_versions (recipe_version_id)
    on delete restrict,
  add constraint master_data_mappings_recipe_line_fkey foreign key (
    recipe_line_id
  ) references atlas_admin.recipe_lines (recipe_line_id)
    on delete restrict,
  add constraint master_data_mappings_recipe_line_revision_fkey foreign key (
    recipe_line_revision_id
  ) references atlas_admin.recipe_line_revisions (recipe_line_revision_id)
    on delete restrict,
  add constraint master_data_mappings_object_type_check check (
    object_type in (
      'CUSTOMER',
      'DELIVERY_LOCATION',
      'SCHOOL_TYPE',
      'SCHOOL',
      'UNIT',
      'INGREDIENT',
      'SUPPLIER',
      'DISH',
      'RECIPE',
      'RECIPE_VERSION',
      'RECIPE_LINE',
      'RECIPE_LINE_REVISION'
    )
  ),
  add constraint master_data_mappings_typed_target_check check (
    (
      object_type = 'CUSTOMER'
      and customer_id is not null
      and num_nonnulls(
        delivery_location_id, school_type_id, school_id, unit_id,
        ingredient_id, supplier_id, dish_id, recipe_id, recipe_version_id,
        recipe_line_id, recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'DELIVERY_LOCATION'
      and delivery_location_id is not null
      and num_nonnulls(
        customer_id, school_type_id, school_id, unit_id, ingredient_id,
        supplier_id, dish_id, recipe_id, recipe_version_id, recipe_line_id,
        recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'SCHOOL_TYPE'
      and school_type_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_id, unit_id, ingredient_id,
        supplier_id, dish_id, recipe_id, recipe_version_id, recipe_line_id,
        recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'SCHOOL'
      and school_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_type_id, unit_id,
        ingredient_id, supplier_id, dish_id, recipe_id, recipe_version_id,
        recipe_line_id, recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'UNIT'
      and unit_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_type_id, school_id,
        ingredient_id, supplier_id, dish_id, recipe_id, recipe_version_id,
        recipe_line_id, recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'INGREDIENT'
      and ingredient_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_type_id, school_id, unit_id,
        supplier_id, dish_id, recipe_id, recipe_version_id, recipe_line_id,
        recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'SUPPLIER'
      and supplier_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_type_id, school_id, unit_id,
        ingredient_id, dish_id, recipe_id, recipe_version_id, recipe_line_id,
        recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'DISH'
      and dish_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_type_id, school_id, unit_id,
        ingredient_id, supplier_id, recipe_id, recipe_version_id,
        recipe_line_id, recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'RECIPE'
      and recipe_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_type_id, school_id, unit_id,
        ingredient_id, supplier_id, dish_id, recipe_version_id,
        recipe_line_id, recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'RECIPE_VERSION'
      and recipe_version_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_type_id, school_id, unit_id,
        ingredient_id, supplier_id, dish_id, recipe_id, recipe_line_id,
        recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'RECIPE_LINE'
      and recipe_line_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_type_id, school_id, unit_id,
        ingredient_id, supplier_id, dish_id, recipe_id, recipe_version_id,
        recipe_line_revision_id
      ) = 0
    )
    or (
      object_type = 'RECIPE_LINE_REVISION'
      and recipe_line_revision_id is not null
      and num_nonnulls(
        customer_id, delivery_location_id, school_type_id, school_id, unit_id,
        ingredient_id, supplier_id, dish_id, recipe_id, recipe_version_id,
        recipe_line_id
      ) = 0
    )
  );

create index master_data_mappings_dish_idx
  on atlas_legacy.master_data_mappings (dish_id)
  where dish_id is not null;
create index master_data_mappings_recipe_idx
  on atlas_legacy.master_data_mappings (recipe_id)
  where recipe_id is not null;
create index master_data_mappings_recipe_version_idx
  on atlas_legacy.master_data_mappings (recipe_version_id)
  where recipe_version_id is not null;
create index master_data_mappings_recipe_line_idx
  on atlas_legacy.master_data_mappings (recipe_line_id)
  where recipe_line_id is not null;
create index master_data_mappings_recipe_line_revision_idx
  on atlas_legacy.master_data_mappings (recipe_line_revision_id)
  where recipe_line_revision_id is not null;

reset role;

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values
  (
    'master_data.recipes.read',
    'Read Dishes, Recipes and BOM',
    'ADMIN',
    'ACTIVE'
  ),
  (
    'master_data.recipes.write',
    'Maintain Dishes, Recipe Drafts and BOM',
    'ADMIN',
    'ACTIVE'
  ),
  (
    'master_data.recipes.validate',
    'Validate Recipe Versions',
    'ADMIN',
    'ACTIVE'
  ),
  (
    'master_data.recipes.release',
    'Release Recipe Versions for Planning',
    'ADMIN',
    'ACTIVE'
  ),
  (
    'master_data.recipes.import',
    'Import Reviewed Recipe Workbooks',
    'ADMIN',
    'ACTIVE'
  );

create or replace function atlas_core.rmvp_02a_read_error(
  request jsonb,
  read_name text,
  error_code text,
  safe_message text,
  field_errors jsonb default '[]'::jsonb
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RMVP-02A.v1',
    'error_code', error_code,
    'safe_message', safe_message,
    'domain', 'ADMIN',
    'read_name', read_name,
    'field_errors', coalesce(field_errors, '[]'::jsonb),
    'correlation_id', request ->> 'correlation_id'
  );
$$;

create or replace function atlas_core.rmvp_02a_validate_read_request(
  request jsonb,
  read_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_02a_read_error(
      coalesce(request, '{}'::jsonb),
      read_name,
      'VALIDATION_FAILED',
      'The read request must be a JSON object.'
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-02A.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use RMVP-02A.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'correlation_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if request -> 'payload' is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'A JSON object is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_02a_read_error(
      request,
      read_name,
      'VALIDATION_FAILED',
      'The read envelope is invalid.',
      v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_core.rmvp_02a_validate_command_request(
  request jsonb,
  command_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
  v_requested_at timestamptz;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb),
      'VALIDATION_FAILED',
      'The command request must be a JSON object.',
      'ADMIN',
      command_name
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-02A.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use RMVP-02A.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'command_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'correlation_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
     or pg_catalog.length(request ->> 'idempotency_key') > 200 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'idempotency_key',
        'message', 'A non-empty key of at most 200 characters is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_version',
        'message', 'A positive integer version is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(
    request ->> 'requested_at'
  );
  if v_requested_at is null
     or v_requested_at > pg_catalog.transaction_timestamp() then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_at',
        'message', 'A valid non-future timestamp is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = '' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason_code',
        'message', 'A reason code is required.'
      )
    );
  end if;
  if not (request ? 'reason_note') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason_note',
        'message', 'reason_note is required and may be null.'
      )
    );
  end if;
  if request -> 'payload' is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'A JSON object is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The command envelope is invalid.',
      'ADMIN',
      command_name,
      false,
      v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_core.rmvp_02a_prepare_command(
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
  v_error := atlas_core.rmvp_02a_validate_command_request(
    request,
    command_name
  );
  if v_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_error
    );
  end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    capability_code,
    command_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_context -> 'error'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    command_name,
    'ADMIN',
    aggregate_scope
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_begin -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY',
    'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

create or replace function atlas_core.rmvp_02a_recipe_version_composition(
  target_recipe_version_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select case
    when version.recipe_version_status = 'DRAFT'
      then version.draft_composition
    else coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'recipe_line_id', revision.recipe_line_id,
            'recipe_line_revision_id', revision.recipe_line_revision_id,
            'predecessor_recipe_line_revision_id',
              revision.predecessor_recipe_line_revision_id,
            'line_revision_number', revision.line_revision_number,
            'ingredient_id', revision.ingredient_id,
            'quantity_per_basis', revision.quantity_per_basis,
            'unit_id', revision.unit_id,
            'line_disposition', revision.line_disposition,
            'operational_note', revision.operational_note,
            'line_code', line.line_code
          )
          order by line.line_code nulls last, revision.recipe_line_id
        )
        from atlas_admin.recipe_line_revisions revision
        join atlas_admin.recipe_lines line
          on line.recipe_line_id = revision.recipe_line_id
        where revision.recipe_version_id = version.recipe_version_id
      ),
      '[]'::jsonb
    )
  end
  from atlas_admin.recipe_versions version
  where version.recipe_version_id = target_recipe_version_id;
$$;

create or replace function atlas_core.rmvp_02a_recipe_workbench_payload()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'dishes',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_id', dish.dish_id,
            'dish_code', dish.dish_code,
            'dish_name', dish.dish_name,
            'dish_category', dish.dish_category,
            'operational_notes', dish.operational_notes,
            'dish_status', dish.dish_status,
            'display_order', dish.display_order,
            'requires_need_generation', dish.requires_need_generation,
            'version', dish.version,
            'created_at', dish.created_at,
            'updated_at', dish.updated_at
          )
          order by dish.display_order, dish.dish_name, dish.dish_id
        )
        from atlas_admin.dishes dish
      ),
      '[]'::jsonb
    ),
    'school_types',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'school_type_id', school_type.school_type_id,
            'school_type_code', school_type.school_type_code,
            'school_type_name', school_type.school_type_name,
            'school_type_status', school_type.school_type_status
          )
          order by school_type.school_type_name, school_type.school_type_id
        )
        from atlas_admin.school_types school_type
      ),
      '[]'::jsonb
    ),
    'ingredients',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'ingredient_id', ingredient.ingredient_id,
            'ingredient_code', ingredient.ingredient_code,
            'ingredient_name', ingredient.ingredient_name,
            'ingredient_status', ingredient.ingredient_status
          )
          order by ingredient.ingredient_name, ingredient.ingredient_id
        )
        from atlas_admin.ingredients ingredient
      ),
      '[]'::jsonb
    ),
    'units',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'unit_id', unit.unit_id,
            'unit_code', unit.unit_code,
            'unit_name', unit.unit_name,
            'unit_status', unit.unit_status
          )
          order by unit.unit_name, unit.unit_id
        )
        from atlas_admin.units unit
      ),
      '[]'::jsonb
    ),
    'recipes',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'recipe_id', recipe.recipe_id,
            'dish_id', recipe.dish_id,
            'school_type_id', recipe.school_type_id,
            'recipe_status', recipe.recipe_status,
            'version', recipe.version,
            'created_at', recipe.created_at,
            'updated_at', recipe.updated_at
          )
          order by recipe.dish_id, recipe.school_type_id nulls first,
            recipe.recipe_id
        )
        from atlas_admin.recipes recipe
      ),
      '[]'::jsonb
    ),
    'recipe_versions',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'recipe_version_id', version.recipe_version_id,
            'recipe_id', version.recipe_id,
            'version_number', version.version_number,
            'predecessor_recipe_version_id',
              version.predecessor_recipe_version_id,
            'basis_portions', version.basis_portions,
            'recipe_version_status', version.recipe_version_status,
            'version', version.version,
            'source_evidence', version.source_evidence,
            'created_by_actor_id', version.created_by_actor_id,
            'created_at', version.created_at,
            'validated_by_actor_id', version.validated_by_actor_id,
            'validated_at', version.validated_at,
            'released_by_actor_id', version.released_by_actor_id,
            'released_at', version.released_at,
            'locked_by_actor_id', version.locked_by_actor_id,
            'locked_at', version.locked_at,
            'composition',
              atlas_core.rmvp_02a_recipe_version_composition(
                version.recipe_version_id
              )
          )
          order by version.recipe_id, version.version_number,
            version.recipe_version_id
        )
        from atlas_admin.recipe_versions version
      ),
      '[]'::jsonb
    )
  );
$$;

create or replace function atlas_core.rmvp_02a_finish_success(
  request jsonb,
  actor_id uuid,
  command_receipt_id uuid,
  event_type text,
  aggregate_type text,
  aggregate_id uuid,
  version_before bigint,
  version_after bigint,
  before_summary jsonb,
  after_summary jsonb,
  safe_operator_message text,
  affected_aggregate_ids jsonb
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
    actor_id,
    command_receipt_id,
    event_type,
    aggregate_type,
    aggregate_id,
    version_before,
    version_after,
    before_summary,
    after_summary
  );
  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02A.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', affected_aggregate_ids,
    'new_versions', pg_catalog.jsonb_build_object(
      'aggregate_version', version_after
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'audit_event_id'
    ),
    'authoritative_readback',
      atlas_core.rmvp_02a_recipe_workbench_payload(),
    'safe_operator_message', safe_operator_message,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(
    command_receipt_id,
    v_response,
    true
  );
end;
$$;

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
begin
  v_error := atlas_core.rmvp_02a_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.recipes.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02A.v1',
    'correlation_id', request ->> 'correlation_id',
    'workbench', atlas_core.rmvp_02a_recipe_workbench_payload(),
    'safe_operator_message', 'Authorized Dish, Recipe, and BOM data returned.'
  );
exception when others then
  return atlas_core.rmvp_02a_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'Dish, Recipe, and BOM data could not be returned safely.'
  );
end;
$$;

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
  v_notes text := nullif(
    pg_catalog.btrim(coalesce(v_payload ->> 'operational_notes', '')),
    ''
  );
  v_display_order bigint := atlas_core.pa_05b_safe_bigint(
    v_payload ->> 'display_order'
  );
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
    v_requires := (v_payload ->> 'requires_need_generation')::boolean;
  exception when others then
    v_requires := null;
  end;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
     or v_code = ''
     or v_dish_name = ''
     or v_display_order is null
     or v_display_order < 0
     or v_display_order > 2147483647
     or v_requires is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Dish values are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload',
          'message',
          'code, name, non-negative display order, and Need Generation choice are required; create uses expected_version 1.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'dish-code:' || v_code
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  if exists (
    select 1
    from atlas_admin.dishes
    where dish_code = v_code
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
    operational_notes,
    dish_status,
    display_order,
    requires_need_generation
  ) values (
    v_code,
    v_dish_name,
    v_category,
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

create or replace function atlas_api.update_dish(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'update_dish';
  v_payload jsonb := request -> 'payload';
  v_dish_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');
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
  v_notes text := nullif(
    pg_catalog.btrim(coalesce(v_payload ->> 'operational_notes', '')),
    ''
  );
  v_display_order bigint := atlas_core.pa_05b_safe_bigint(
    v_payload ->> 'display_order'
  );
  v_requires boolean;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_dish atlas_admin.dishes%rowtype;
  v_before jsonb;
  v_after jsonb;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  begin
    v_requires := (v_payload ->> 'requires_need_generation')::boolean;
  exception when others then
    v_requires := null;
  end;
  if v_dish_id is null
     or v_code = ''
     or v_dish_name = ''
     or v_display_order is null
     or v_display_order < 0
     or v_display_order > 2147483647
     or v_requires is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Dish values are incomplete or invalid.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'dish:' || v_dish_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_dish
  from atlas_admin.dishes
  where dish_id = v_dish_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The dish was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_dish.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The dish changed after it was read. Refresh before saving.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_dish.version
      ),
      false
    );
  end if;
  if exists (
    select 1
    from atlas_admin.dishes other_dish
    where other_dish.dish_id <> v_dish_id
      and other_dish.dish_code = v_code
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
  if v_dish.dish_status = 'ACTIVE' and exists (
    select 1
    from atlas_admin.dishes other_dish
    where other_dish.dish_id <> v_dish_id
      and other_dish.dish_status = 'ACTIVE'
      and pg_catalog.lower(pg_catalog.btrim(other_dish.dish_name))
        = pg_catalog.lower(v_dish_name)
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'An active dish with this normalized name already exists.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'dish_code', v_dish.dish_code,
    'dish_name', v_dish.dish_name,
    'dish_category', v_dish.dish_category,
    'operational_notes', v_dish.operational_notes,
    'display_order', v_dish.display_order,
    'requires_need_generation', v_dish.requires_need_generation
  );
  update atlas_admin.dishes
  set dish_code = v_code,
      dish_name = v_dish_name,
      dish_category = v_category,
      operational_notes = v_notes,
      display_order = v_display_order::integer,
      requires_need_generation = v_requires,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where dish_id = v_dish_id;
  v_after := pg_catalog.jsonb_build_object(
    'dish_code', v_code,
    'dish_name', v_dish_name,
    'dish_category', v_category,
    'operational_notes', v_notes,
    'display_order', v_display_order,
    'requires_need_generation', v_requires
  );
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'DishUpdated',
    'Dish',
    v_dish_id,
    v_dish.version,
    v_dish.version + 1,
    v_before,
    v_after,
    'Dish details saved.',
    pg_catalog.jsonb_build_object('dish_id', v_dish_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The dish could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The dish code or active normalized name is already in use.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The dish could not be saved safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.set_dish_lifecycle(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'set_dish_lifecycle';
  v_payload jsonb := request -> 'payload';
  v_dish_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');
  v_target_status text := pg_catalog.upper(
    pg_catalog.btrim(coalesce(v_payload ->> 'dish_status', ''))
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_dish atlas_admin.dishes%rowtype;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_dish_id is null or v_target_status not in ('ACTIVE', 'INACTIVE') then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Dish lifecycle values are invalid.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'dish:' || v_dish_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_dish
  from atlas_admin.dishes
  where dish_id = v_dish_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The dish was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_dish.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The dish changed after it was read. Refresh before changing status.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_dish.version
      ),
      false
    );
  end if;
  if v_dish.dish_status = v_target_status
     or not (
       (v_dish.dish_status = 'DRAFT' and v_target_status = 'ACTIVE')
       or (v_dish.dish_status = 'ACTIVE' and v_target_status = 'INACTIVE')
       or (v_dish.dish_status = 'INACTIVE' and v_target_status = 'ACTIVE')
     ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'The requested dish lifecycle transition is not allowed.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if v_target_status = 'ACTIVE' and exists (
    select 1
    from atlas_admin.dishes other_dish
    where other_dish.dish_id <> v_dish_id
      and other_dish.dish_status = 'ACTIVE'
      and pg_catalog.lower(pg_catalog.btrim(other_dish.dish_name))
        = pg_catalog.lower(pg_catalog.btrim(v_dish.dish_name))
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'An active dish with this normalized name already exists.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  update atlas_admin.dishes
  set dish_status = v_target_status,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where dish_id = v_dish_id;
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    case
      when v_target_status = 'ACTIVE' then 'DishActivated'
      else 'DishDeactivated'
    end,
    'Dish',
    v_dish_id,
    v_dish.version,
    v_dish.version + 1,
    pg_catalog.jsonb_build_object('dish_status', v_dish.dish_status),
    pg_catalog.jsonb_build_object('dish_status', v_target_status),
    case
      when v_target_status = 'ACTIVE' then 'Dish activated.'
      else 'Dish deactivated; historical references were preserved.'
    end,
    pg_catalog.jsonb_build_object('dish_id', v_dish_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The dish could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The active normalized dish name is already in use.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The dish status could not be changed safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.set_recipe_lifecycle(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'set_recipe_lifecycle';
  v_payload jsonb := request -> 'payload';
  v_recipe_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'recipe_id');
  v_target_status text := pg_catalog.upper(
    pg_catalog.btrim(coalesce(v_payload ->> 'recipe_status', ''))
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_recipe atlas_admin.recipes%rowtype;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_recipe_id is null or v_target_status not in ('ACTIVE', 'INACTIVE') then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Recipe lifecycle values are invalid.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'recipe:' || v_recipe_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_recipe
  from atlas_admin.recipes
  where recipe_id = v_recipe_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The recipe root was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_recipe.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The recipe root changed after it was read. Refresh before saving.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_recipe.version
      ),
      false
    );
  end if;
  if v_recipe.recipe_status = v_target_status then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'The recipe root already has this lifecycle status.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  update atlas_admin.recipes
  set recipe_status = v_target_status,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where recipe_id = v_recipe_id;
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    case
      when v_target_status = 'ACTIVE' then 'RecipeActivated'
      else 'RecipeDeactivated'
    end,
    'Recipe',
    v_recipe_id,
    v_recipe.version,
    v_recipe.version + 1,
    pg_catalog.jsonb_build_object('recipe_status', v_recipe.recipe_status),
    pg_catalog.jsonb_build_object('recipe_status', v_target_status),
    case
      when v_target_status = 'ACTIVE' then 'Recipe root activated.'
      else 'Recipe root deactivated; version history was preserved.'
    end,
    pg_catalog.jsonb_build_object(
      'recipe_id', v_recipe_id,
      'dish_id', v_recipe.dish_id
    )
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'An active recipe root already exists for this Dish and School Type scope.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The recipe status could not be changed safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.create_recipe_draft(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_recipe_draft';
  v_payload jsonb := request -> 'payload';
  v_dish_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');
  v_school_type_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'school_type_id'
  );
  v_basis bigint := atlas_core.pa_05b_safe_bigint(
    v_payload ->> 'basis_portions'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_dish atlas_admin.dishes%rowtype;
  v_recipe atlas_admin.recipes%rowtype;
  v_recipe_id uuid;
  v_recipe_version_id uuid;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_dish_id is null
     or v_basis is null
     or v_basis <= 0
     or v_basis > 2147483647
     or (
       v_payload ? 'school_type_id'
       and v_payload ->> 'school_type_id' is not null
       and v_school_type_id is null
     ) then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Recipe scope or basis is invalid.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'dish-recipe:' || v_dish_id::text || ':' ||
      coalesce(v_school_type_id::text, 'general')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_dish
  from atlas_admin.dishes
  where dish_id = v_dish_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The dish was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_dish.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The dish changed after it was read. Refresh before creating a recipe.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_dish.version
      ),
      false
    );
  end if;
  if v_school_type_id is not null and not exists (
    select 1
    from atlas_admin.school_types
    where school_type_id = v_school_type_id
      and school_type_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The selected School Type is not active.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select * into v_recipe
  from atlas_admin.recipes recipe
  where recipe.dish_id = v_dish_id
    and recipe.school_type_id is not distinct from v_school_type_id
    and recipe.recipe_status = 'ACTIVE'
  for update;
  if found then
    if exists (
      select 1
      from atlas_admin.recipe_versions version
      where version.recipe_id = v_recipe.recipe_id
    ) then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'CONFLICT',
          'This recipe scope already has version history.',
          'ADMIN',
          v_name
        ),
        false
      );
    end if;
    v_recipe_id := v_recipe.recipe_id;
  else
    insert into atlas_admin.recipes (
      dish_id,
      school_type_id,
      recipe_status
    ) values (
      v_dish_id,
      v_school_type_id,
      'ACTIVE'
    )
    returning recipe_id into v_recipe_id;
  end if;
  insert into atlas_admin.recipe_versions (
    recipe_id,
    version_number,
    basis_portions,
    recipe_version_status,
    created_by_actor_id,
    source_evidence
  ) values (
    v_recipe_id,
    1,
    v_basis::integer,
    'DRAFT',
    v_actor_id,
    pg_catalog.jsonb_build_object(
      'source_kind', 'MANUAL_INITIAL_DRAFT',
      'reason_note', request ->> 'reason_note'
    )
  )
  returning recipe_version_id into v_recipe_version_id;
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeDraftCreated',
    'RecipeVersion',
    v_recipe_version_id,
    null,
    1,
    null,
    pg_catalog.jsonb_build_object(
      'recipe_id', v_recipe_id,
      'recipe_version_id', v_recipe_version_id,
      'version_number', 1,
      'basis_portions', v_basis,
      'recipe_version_status', 'DRAFT'
    ),
    'Initial recipe draft created.',
    pg_catalog.jsonb_build_object(
      'dish_id', v_dish_id,
      'recipe_id', v_recipe_id,
      'recipe_version_id', v_recipe_version_id
    )
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The recipe scope or initial version was created concurrently.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The recipe draft could not be created safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.create_recipe_successor_version(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_recipe_successor_version';
  v_payload jsonb := request -> 'payload';
  v_source_version_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'recipe_version_id'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_source atlas_admin.recipe_versions%rowtype;
  v_recipe atlas_admin.recipes%rowtype;
  v_new_version_id uuid;
  v_next_number integer;
  v_composition jsonb;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_source_version_id is null
     or pg_catalog.btrim(coalesce(request ->> 'reason_note', '')) = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'A source version and concise correction reason are required.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'recipe-version:' || v_source_version_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_source
  from atlas_admin.recipe_versions
  where recipe_version_id = v_source_version_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The source recipe version was not found.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_source.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The source version changed after it was read. Refresh before creating a successor.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_source.version
      ),
      false
    );
  end if;
  if v_source.recipe_version_status not in (
    'VALIDATED',
    'RELEASED_FOR_PLANNING',
    'LOCKED'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'A successor correction must start from a materialized non-draft version.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select * into v_recipe
  from atlas_admin.recipes
  where recipe_id = v_source.recipe_id
  for update;
  if v_recipe.recipe_status <> 'ACTIVE' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'An inactive recipe root cannot receive a new successor.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if exists (
    select 1
    from atlas_admin.recipe_versions version
    where version.recipe_id = v_source.recipe_id
      and version.recipe_version_status in ('DRAFT', 'VALIDATED')
      and version.recipe_version_id <> v_source.recipe_version_id
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'This recipe already has an unfinished draft or validated successor.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select coalesce(pg_catalog.max(version_number), 0) + 1
  into v_next_number
  from atlas_admin.recipe_versions
  where recipe_id = v_source.recipe_id;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'recipe_line_id', revision.recipe_line_id,
        'predecessor_recipe_line_revision_id',
          revision.recipe_line_revision_id,
        'ingredient_id', revision.ingredient_id,
        'quantity_per_basis', revision.quantity_per_basis,
        'unit_id', revision.unit_id,
        'line_disposition', 'PRESENT',
        'operational_note', revision.operational_note,
        'line_code', line.line_code
      )
      order by line.line_code nulls last, revision.recipe_line_id
    ),
    '[]'::jsonb
  )
  into v_composition
  from atlas_admin.recipe_line_revisions revision
  join atlas_admin.recipe_lines line
    on line.recipe_line_id = revision.recipe_line_id
  where revision.recipe_version_id = v_source.recipe_version_id
    and revision.line_disposition = 'PRESENT';
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
    v_source.recipe_id,
    v_next_number,
    v_source.recipe_version_id,
    v_source.basis_portions,
    'DRAFT',
    v_actor_id,
    v_composition,
    pg_catalog.jsonb_build_object(
      'source_kind', 'MANUAL_SUCCESSOR',
      'source_recipe_version_id', v_source.recipe_version_id,
      'reason_note', request ->> 'reason_note'
    )
  )
  returning recipe_version_id into v_new_version_id;
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeSuccessorVersionCreated',
    'RecipeVersion',
    v_new_version_id,
    null,
    1,
    null,
    pg_catalog.jsonb_build_object(
      'recipe_id', v_source.recipe_id,
      'recipe_version_id', v_new_version_id,
      'version_number', v_next_number,
      'predecessor_recipe_version_id', v_source.recipe_version_id,
      'copied_line_count', pg_catalog.jsonb_array_length(v_composition)
    ),
    'Successor draft created; prior materialized history is unchanged.',
    pg_catalog.jsonb_build_object(
      'dish_id', v_recipe.dish_id,
      'recipe_id', v_source.recipe_id,
      'recipe_version_id', v_new_version_id
    )
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'A successor version was created concurrently.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The successor version could not be created safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.replace_recipe_draft_composition(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'replace_recipe_draft_composition';
  v_payload jsonb := request -> 'payload';
  v_recipe_version_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'recipe_version_id'
  );
  v_basis bigint := atlas_core.pa_05b_safe_bigint(
    v_payload ->> 'basis_portions'
  );
  v_lines jsonb := v_payload -> 'lines';
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_version atlas_admin.recipe_versions%rowtype;
  v_recipe atlas_admin.recipes%rowtype;
  v_composition jsonb;
  v_line_count integer;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_recipe_version_id is null
     or v_basis is null
     or v_basis <= 0
     or v_basis > 2147483647
     or v_lines is null
     or pg_catalog.jsonb_typeof(v_lines) <> 'array'
     or pg_catalog.jsonb_array_length(v_lines) > 500
     or pg_catalog.btrim(coalesce(request ->> 'reason_note', '')) = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Draft composition, positive basis, and a concise change reason are required.',
      'ADMIN',
      v_name
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_lines) item
    where pg_catalog.jsonb_typeof(item) <> 'object'
      or atlas_core.pa_05b_safe_uuid(item ->> 'ingredient_id') is null
      or atlas_core.pa_05b_safe_uuid(item ->> 'unit_id') is null
      or (
        item ? 'recipe_line_id'
        and item ->> 'recipe_line_id' is not null
        and atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id') is null
      )
      or (
        item ? 'predecessor_recipe_line_revision_id'
        and item ->> 'predecessor_recipe_line_revision_id' is not null
        and atlas_core.pa_05b_safe_uuid(
          item ->> 'predecessor_recipe_line_revision_id'
        ) is null
      )
      or coalesce(
        pg_catalog.upper(item ->> 'line_disposition'),
        'PRESENT'
      ) not in ('PRESENT', 'REMOVED')
      or atlas_core.pa_05b_safe_numeric(
        item ->> 'quantity_per_basis'
      ) is null
      or (
        coalesce(
          pg_catalog.upper(item ->> 'line_disposition'),
          'PRESENT'
        ) = 'PRESENT'
        and atlas_core.pa_05b_safe_numeric(
          item ->> 'quantity_per_basis'
        ) <= 0
      )
      or (
        coalesce(
          pg_catalog.upper(item ->> 'line_disposition'),
          'PRESENT'
        ) = 'REMOVED'
        and (
          atlas_core.pa_05b_safe_numeric(
            item ->> 'quantity_per_basis'
          ) <> 0
          or atlas_core.pa_05b_safe_uuid(
            item ->> 'predecessor_recipe_line_revision_id'
          ) is null
        )
      )
  ) then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'One or more BOM rows are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.lines',
          'message',
          'PRESENT rows require active references and positive quantities; REMOVED rows require an exact predecessor and zero quantity.'
        )
      )
    );
  end if;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'recipe_line_id',
          coalesce(
            atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id'),
            gen_random_uuid()
          ),
        'predecessor_recipe_line_revision_id',
          atlas_core.pa_05b_safe_uuid(
            item ->> 'predecessor_recipe_line_revision_id'
          ),
        'ingredient_id',
          atlas_core.pa_05b_safe_uuid(item ->> 'ingredient_id'),
        'quantity_per_basis',
          atlas_core.pa_05b_safe_numeric(item ->> 'quantity_per_basis'),
        'unit_id', atlas_core.pa_05b_safe_uuid(item ->> 'unit_id'),
        'line_disposition',
          coalesce(
            pg_catalog.upper(item ->> 'line_disposition'),
            'PRESENT'
          ),
        'operational_note',
          nullif(
            pg_catalog.btrim(coalesce(item ->> 'operational_note', '')),
            ''
          ),
        'line_code',
          nullif(
            pg_catalog.lower(
              pg_catalog.btrim(coalesce(item ->> 'line_code', ''))
            ),
            ''
          )
      )
      order by ordinal
    ),
    '[]'::jsonb
  )
  into v_composition
  from pg_catalog.jsonb_array_elements(v_lines)
    with ordinality source(item, ordinal);
  v_line_count := pg_catalog.jsonb_array_length(v_composition);
  if (
    select count(distinct item ->> 'recipe_line_id')
    from pg_catalog.jsonb_array_elements(v_composition) item
  ) <> v_line_count then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'A stable Recipe Line may appear only once in a draft composition.',
      'ADMIN',
      v_name
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_composition) item
    where item ->> 'line_disposition' = 'PRESENT'
    group by item ->> 'ingredient_id'
    having count(*) > 1
  ) then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Duplicate ingredient contributions are not allowed in one recipe version.',
      'ADMIN',
      v_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'DUPLICATE_INGREDIENT',
          'message', 'Combine the ingredient into one BOM contribution.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'recipe-version:' || v_recipe_version_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_version
  from atlas_admin.recipe_versions
  where recipe_version_id = v_recipe_version_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The recipe version was not found.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_version.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The recipe or composition changed after it was read. Refresh before saving.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_version.version
      ),
      false
    );
  end if;
  if v_version.recipe_version_status <> 'DRAFT' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only a DRAFT Recipe Version composition can be replaced.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select * into v_recipe
  from atlas_admin.recipes
  where recipe_id = v_version.recipe_id
  for key share;
  if v_recipe.recipe_status <> 'ACTIVE' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'An inactive recipe root cannot accept new composition.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_composition) item
    left join atlas_admin.recipe_lines line
      on line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
        item ->> 'recipe_line_id'
      )
    where line.recipe_line_id is not null
      and line.recipe_id <> v_version.recipe_id
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'A stable Recipe Line belongs to a different Recipe.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_composition) item
    join atlas_admin.recipe_line_revisions predecessor
      on predecessor.recipe_line_revision_id =
        atlas_core.pa_05b_safe_uuid(
          item ->> 'predecessor_recipe_line_revision_id'
        )
    where predecessor.recipe_id <> v_version.recipe_id
      or predecessor.recipe_version_id
        is distinct from v_version.predecessor_recipe_version_id
      or predecessor.recipe_line_id <> atlas_core.pa_05b_safe_uuid(
        item ->> 'recipe_line_id'
      )
  ) or exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_composition) item
    where item ->> 'predecessor_recipe_line_revision_id' is not null
      and not exists (
        select 1
        from atlas_admin.recipe_line_revisions predecessor
        where predecessor.recipe_line_revision_id =
          atlas_core.pa_05b_safe_uuid(
            item ->> 'predecessor_recipe_line_revision_id'
          )
      )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'A line predecessor does not belong to the exact Recipe and predecessor version.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if v_version.predecessor_recipe_version_id is null and exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_composition) item
    where item ->> 'predecessor_recipe_line_revision_id' is not null
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'An initial version cannot reference predecessor line revisions.',
        'ADMIN',
        v_name
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
        from pg_catalog.jsonb_array_elements(v_composition) item
        where atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id')
          = predecessor.recipe_line_id
          and atlas_core.pa_05b_safe_uuid(
            item ->> 'predecessor_recipe_line_revision_id'
          ) = predecessor.recipe_line_revision_id
      )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Every previously present line requires an explicit successor or removal.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', 'SILENT_LINE_OMISSION',
            'message', 'Retain the line or mark it REMOVED explicitly.'
          )
        )
      ),
      false
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_composition) item
    join atlas_admin.recipe_lines line
      on line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
        item ->> 'recipe_line_id'
      )
    where item ->> 'predecessor_recipe_line_revision_id' is null
      and exists (
        select 1
        from atlas_admin.recipe_line_revisions revision
        where revision.recipe_line_id = line.recipe_line_id
      )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'An existing stable Recipe Line requires its exact predecessor revision.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if exists (
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
      )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Every PRESENT line requires an active Ingredient and active Unit.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_composition) item
    join atlas_admin.recipe_line_revisions predecessor
      on predecessor.recipe_line_revision_id =
        atlas_core.pa_05b_safe_uuid(
          item ->> 'predecessor_recipe_line_revision_id'
        )
    where item ->> 'line_disposition' = 'REMOVED'
      and (
        atlas_core.pa_05b_safe_uuid(item ->> 'ingredient_id')
          <> predecessor.ingredient_id
        or atlas_core.pa_05b_safe_uuid(item ->> 'unit_id')
          <> predecessor.unit_id
      )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'A REMOVED row must preserve its predecessor Ingredient and Unit evidence.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  insert into atlas_admin.recipe_lines (
    recipe_line_id,
    recipe_id,
    line_code
  )
  select
    atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id'),
    v_version.recipe_id,
    nullif(item ->> 'line_code', '')
  from pg_catalog.jsonb_array_elements(v_composition) item
  where not exists (
    select 1
    from atlas_admin.recipe_lines line
    where line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
      item ->> 'recipe_line_id'
    )
  );
  update atlas_admin.recipe_versions
  set basis_portions = v_basis::integer,
      draft_composition = v_composition,
      version = version + 1
  where recipe_version_id = v_recipe_version_id;
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeDraftCompositionReplaced',
    'RecipeVersion',
    v_recipe_version_id,
    v_version.version,
    v_version.version + 1,
    pg_catalog.jsonb_build_object(
      'basis_portions', v_version.basis_portions,
      'line_count',
        pg_catalog.jsonb_array_length(v_version.draft_composition)
    ),
    pg_catalog.jsonb_build_object(
      'basis_portions', v_basis,
      'line_count', v_line_count
    ),
    'Draft composition replaced atomically and read back.',
    pg_catalog.jsonb_build_object(
      'dish_id', v_recipe.dish_id,
      'recipe_id', v_version.recipe_id,
      'recipe_version_id', v_recipe_version_id
    )
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The draft could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The draft composition could not be replaced safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.validate_recipe_version(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'validate_recipe_version';
  v_payload jsonb := request -> 'payload';
  v_recipe_version_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'recipe_version_id'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_version atlas_admin.recipe_versions%rowtype;
  v_recipe atlas_admin.recipes%rowtype;
  v_dish atlas_admin.dishes%rowtype;
  v_line_count integer;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_recipe_version_id is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'A Recipe Version is required.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.validate',
    'recipe-version:' || v_recipe_version_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_version
  from atlas_admin.recipe_versions
  where recipe_version_id = v_recipe_version_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The recipe version was not found.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_version.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The recipe or composition changed after it was read. Refresh before validating.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_version.version
      ),
      false
    );
  end if;
  if v_version.recipe_version_status <> 'DRAFT' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only a DRAFT Recipe Version can be validated.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select * into v_recipe
  from atlas_admin.recipes
  where recipe_id = v_version.recipe_id
  for key share;
  select * into v_dish
  from atlas_admin.dishes
  where dish_id = v_recipe.dish_id
  for key share;
  if v_recipe.recipe_status <> 'ACTIVE'
     or v_dish.dish_status <> 'ACTIVE' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'The Dish and Recipe root must be active before validation.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  v_line_count := (
    select count(*)::integer
    from pg_catalog.jsonb_array_elements(v_version.draft_composition) item
    where item ->> 'line_disposition' = 'PRESENT'
  );
  if v_dish.requires_need_generation and v_line_count = 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'A Need-Generation Dish cannot validate an empty composition.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'code', 'EMPTY_NEED_GENERATION_RECIPE',
            'message', 'Add at least one PRESENT BOM line.'
          )
        )
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
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Every PRESENT BOM row requires active references and a positive quantity.',
        'ADMIN',
        v_name
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
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Every previously present line requires an explicit successor or removal.',
        'ADMIN',
        v_name
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
  from pg_catalog.jsonb_array_elements(
    v_version.draft_composition
  ) item
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
    from pg_catalog.jsonb_array_elements(
      v_version.draft_composition
    ) item
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

  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeVersionValidated',
    'RecipeVersion',
    v_recipe_version_id,
    v_version.version,
    v_version.version + 1,
    pg_catalog.jsonb_build_object(
      'recipe_version_status', 'DRAFT',
      'line_count',
        pg_catalog.jsonb_array_length(v_version.draft_composition)
    ),
    pg_catalog.jsonb_build_object(
      'recipe_version_status', 'VALIDATED',
      'line_count',
        pg_catalog.jsonb_array_length(v_version.draft_composition)
    ),
    'Recipe Version validated and immutable composition materialized.',
    pg_catalog.jsonb_build_object(
      'dish_id', v_dish.dish_id,
      'recipe_id', v_version.recipe_id,
      'recipe_version_id', v_recipe_version_id
    )
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Recipe Version could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Recipe Version could not be validated safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.release_recipe_version_for_planning(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'release_recipe_version_for_planning';
  v_payload jsonb := request -> 'payload';
  v_recipe_version_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'recipe_version_id'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_version atlas_admin.recipe_versions%rowtype;
  v_recipe atlas_admin.recipes%rowtype;
  v_dish atlas_admin.dishes%rowtype;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_recipe_version_id is null
     or pg_catalog.btrim(coalesce(request ->> 'reason_note', '')) = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'A Recipe Version and release reason are required.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.release',
    'recipe-version:' || v_recipe_version_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_version
  from atlas_admin.recipe_versions
  where recipe_version_id = v_recipe_version_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The recipe version was not found.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_version.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The Recipe Version changed after it was read. Refresh before releasing.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_version.version
      ),
      false
    );
  end if;
  if v_version.recipe_version_status <> 'VALIDATED' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only a VALIDATED Recipe Version can be released for Planning.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select * into v_recipe
  from atlas_admin.recipes
  where recipe_id = v_version.recipe_id
  for key share;
  select * into v_dish
  from atlas_admin.dishes
  where dish_id = v_recipe.dish_id
  for key share;
  if v_recipe.recipe_status <> 'ACTIVE'
     or v_dish.dish_status <> 'ACTIVE' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'The Dish and Recipe root must be active before release.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if exists (
    select 1
    from atlas_admin.recipe_line_revisions revision
    left join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = revision.ingredient_id
    left join atlas_admin.units unit on unit.unit_id = revision.unit_id
    where revision.recipe_version_id = v_recipe_version_id
      and revision.line_disposition = 'PRESENT'
      and (
        ingredient.ingredient_status <> 'ACTIVE'
        or unit.unit_status <> 'ACTIVE'
      )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'A PRESENT BOM reference became inactive after validation.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  update atlas_admin.recipe_versions
  set recipe_version_status = 'RELEASED_FOR_PLANNING',
      released_by_actor_id = v_actor_id,
      released_at = pg_catalog.transaction_timestamp(),
      version = version + 1
  where recipe_version_id = v_recipe_version_id;
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeVersionReleasedForPlanning',
    'RecipeVersion',
    v_recipe_version_id,
    v_version.version,
    v_version.version + 1,
    pg_catalog.jsonb_build_object(
      'recipe_version_status', 'VALIDATED'
    ),
    pg_catalog.jsonb_build_object(
      'recipe_version_status', 'RELEASED_FOR_PLANNING',
      'effect', 'FUTURE_PLANNING_REFERENCE_ONLY'
    ),
    'Recipe Version released for future Planning; prior operational facts were not recalculated.',
    pg_catalog.jsonb_build_object(
      'dish_id', v_dish.dish_id,
      'recipe_id', v_version.recipe_id,
      'recipe_version_id', v_recipe_version_id
    )
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'Another current Recipe Version release was created concurrently.',
      'ADMIN',
      v_name
    );
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Recipe Version could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Recipe Version could not be released safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.copy_recipe_version(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'copy_recipe_version';
  v_payload jsonb := request -> 'payload';
  v_source_version_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'source_recipe_version_id'
  );
  v_target_dish_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'target_dish_id'
  );
  v_target_school_type_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'target_school_type_id'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_source_version atlas_admin.recipe_versions%rowtype;
  v_source_recipe atlas_admin.recipes%rowtype;
  v_source_dish atlas_admin.dishes%rowtype;
  v_target_dish atlas_admin.dishes%rowtype;
  v_target_recipe atlas_admin.recipes%rowtype;
  v_target_recipe_id uuid;
  v_target_predecessor_id uuid;
  v_new_version_id uuid;
  v_next_number integer;
  v_composition jsonb;
  v_line_count integer;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_source_version_id is null
     or v_target_dish_id is null
     or (
       v_payload ? 'target_school_type_id'
       and v_payload ->> 'target_school_type_id' is not null
       and v_target_school_type_id is null
     )
     or pg_catalog.btrim(coalesce(request ->> 'reason_note', '')) = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Source version, target scope, and copy reason are required.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'recipe-copy:' || v_target_dish_id::text || ':' ||
      coalesce(v_target_school_type_id::text, 'general')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_source_version
  from atlas_admin.recipe_versions
  where recipe_version_id = v_source_version_id
  for key share;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The source Recipe Version was not found.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_source_version.recipe_version_status = 'DRAFT' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only materialized validated, released, or locked composition can be copied.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select * into v_source_recipe
  from atlas_admin.recipes
  where recipe_id = v_source_version.recipe_id
  for key share;
  select * into v_source_dish
  from atlas_admin.dishes
  where dish_id = v_source_recipe.dish_id
  for key share;
  select * into v_target_dish
  from atlas_admin.dishes
  where dish_id = v_target_dish_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The target Dish was not found.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_target_dish.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The target Dish changed after the copy preview. Refresh before applying.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_target_dish.version
      ),
      false
    );
  end if;
  if v_source_dish.dish_status <> 'ACTIVE'
     or v_source_recipe.recipe_status <> 'ACTIVE'
     or v_target_dish.dish_status = 'INACTIVE' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Source references must be active and the target Dish must not be inactive.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if v_target_school_type_id is not null and not exists (
    select 1
    from atlas_admin.school_types
    where school_type_id = v_target_school_type_id
      and school_type_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The target School Type is not active.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if exists (
    select 1
    from atlas_admin.recipe_line_revisions revision
    left join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = revision.ingredient_id
    left join atlas_admin.units unit on unit.unit_id = revision.unit_id
    where revision.recipe_version_id = v_source_version_id
      and revision.line_disposition = 'PRESENT'
      and (
        ingredient.ingredient_status <> 'ACTIVE'
        or unit.unit_status <> 'ACTIVE'
      )
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Inactive or missing source references block recipe copy.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select * into v_target_recipe
  from atlas_admin.recipes recipe
  where recipe.dish_id = v_target_dish_id
    and recipe.school_type_id is not distinct from v_target_school_type_id
    and recipe.recipe_status = 'ACTIVE'
  for update;
  if found then
    if v_target_recipe.recipe_id = v_source_recipe.recipe_id then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'VALIDATION_FAILED',
          'Source and target Recipe roots must be different.',
          'ADMIN',
          v_name
        ),
        false
      );
    end if;
    v_target_recipe_id := v_target_recipe.recipe_id;
  else
    insert into atlas_admin.recipes (
      dish_id,
      school_type_id,
      recipe_status
    ) values (
      v_target_dish_id,
      v_target_school_type_id,
      'ACTIVE'
    )
    returning recipe_id into v_target_recipe_id;
  end if;
  if exists (
    select 1
    from atlas_admin.recipe_versions version
    where version.recipe_id = v_target_recipe_id
      and version.recipe_version_status in ('DRAFT', 'VALIDATED')
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'The target Recipe already has an unfinished draft or validated version.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  select version.recipe_version_id
  into v_target_predecessor_id
  from atlas_admin.recipe_versions version
  where version.recipe_id = v_target_recipe_id
    and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
  order by version.version_number desc
  limit 1;
  if v_target_predecessor_id is null then
    select version.recipe_version_id
    into v_target_predecessor_id
    from atlas_admin.recipe_versions version
    where version.recipe_id = v_target_recipe_id
      and version.recipe_version_status = 'LOCKED'
    order by version.version_number desc
    limit 1;
  end if;
  select coalesce(pg_catalog.max(version_number), 0) + 1
  into v_next_number
  from atlas_admin.recipe_versions
  where recipe_id = v_target_recipe_id;

  with source_lines as (
    select
      source_revision.recipe_line_revision_id
        as source_recipe_line_revision_id,
      source_revision.recipe_line_id as source_recipe_line_id,
      source_revision.ingredient_id,
      source_revision.quantity_per_basis,
      source_revision.unit_id,
      source_revision.operational_note,
      source_line.line_code
    from atlas_admin.recipe_line_revisions source_revision
    join atlas_admin.recipe_lines source_line
      on source_line.recipe_line_id = source_revision.recipe_line_id
    where source_revision.recipe_version_id = v_source_version_id
      and source_revision.line_disposition = 'PRESENT'
  ),
  target_lines as (
    select
      target_revision.recipe_line_revision_id,
      target_revision.recipe_line_id,
      target_revision.ingredient_id,
      target_revision.quantity_per_basis,
      target_revision.unit_id,
      target_revision.operational_note,
      target_line.line_code
    from atlas_admin.recipe_line_revisions target_revision
    join atlas_admin.recipe_lines target_line
      on target_line.recipe_line_id = target_revision.recipe_line_id
    where target_revision.recipe_version_id = v_target_predecessor_id
      and target_revision.line_disposition = 'PRESENT'
  ),
  copied as (
    select
      coalesce(target.recipe_line_id, gen_random_uuid()) as recipe_line_id,
      target.recipe_line_revision_id
        as predecessor_recipe_line_revision_id,
      source.ingredient_id,
      source.quantity_per_basis,
      source.unit_id,
      'PRESENT'::text as line_disposition,
      source.operational_note,
      coalesce(target.line_code, source.line_code) as line_code,
      source.source_recipe_line_revision_id
    from source_lines source
    left join target_lines target
      on target.ingredient_id = source.ingredient_id
  ),
  removed as (
    select
      target.recipe_line_id,
      target.recipe_line_revision_id
        as predecessor_recipe_line_revision_id,
      target.ingredient_id,
      0::numeric as quantity_per_basis,
      target.unit_id,
      'REMOVED'::text as line_disposition,
      target.operational_note,
      target.line_code,
      null::uuid as source_recipe_line_revision_id
    from target_lines target
    where not exists (
      select 1
      from source_lines source
      where source.ingredient_id = target.ingredient_id
    )
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'recipe_line_id', composition.recipe_line_id,
        'predecessor_recipe_line_revision_id',
          composition.predecessor_recipe_line_revision_id,
        'ingredient_id', composition.ingredient_id,
        'quantity_per_basis', composition.quantity_per_basis,
        'unit_id', composition.unit_id,
        'line_disposition', composition.line_disposition,
        'operational_note', composition.operational_note,
        'line_code', composition.line_code,
        'source_recipe_line_revision_id',
          composition.source_recipe_line_revision_id
      )
      order by composition.line_disposition, composition.ingredient_id
    ),
    '[]'::jsonb
  )
  into v_composition
  from (
    select * from copied
    union all
    select * from removed
  ) composition;
  v_line_count := (
    select count(*)::integer
    from pg_catalog.jsonb_array_elements(v_composition) item
    where item ->> 'line_disposition' = 'PRESENT'
  );
  if v_target_dish.requires_need_generation and v_line_count = 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'A Need-Generation target cannot receive an empty copied composition.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  insert into atlas_admin.recipe_lines (
    recipe_line_id,
    recipe_id,
    line_code
  )
  select
    atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id'),
    v_target_recipe_id,
    nullif(item ->> 'line_code', '')
  from pg_catalog.jsonb_array_elements(v_composition) item
  where not exists (
    select 1
    from atlas_admin.recipe_lines line
    where line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
      item ->> 'recipe_line_id'
    )
  );
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
    v_target_recipe_id,
    v_next_number,
    v_target_predecessor_id,
    v_source_version.basis_portions,
    'DRAFT',
    v_actor_id,
    v_composition,
    pg_catalog.jsonb_build_object(
      'source_kind', 'RECIPE_COPY',
      'source_dish_id', v_source_dish.dish_id,
      'source_recipe_id', v_source_recipe.recipe_id,
      'source_recipe_version_id', v_source_version_id,
      'reason_note', request ->> 'reason_note'
    )
  )
  returning recipe_version_id into v_new_version_id;
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'RecipeVersionCopied',
    'RecipeVersion',
    v_new_version_id,
    null,
    1,
    null,
    pg_catalog.jsonb_build_object(
      'source_recipe_version_id', v_source_version_id,
      'target_recipe_id', v_target_recipe_id,
      'target_recipe_version_id', v_new_version_id,
      'line_count', v_line_count,
      'predecessor_recipe_version_id', v_target_predecessor_id
    ),
    'Recipe copy created a new target draft without overwriting history.',
    pg_catalog.jsonb_build_object(
      'dish_id', v_target_dish_id,
      'recipe_id', v_target_recipe_id,
      'recipe_version_id', v_new_version_id
    )
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The target Recipe or draft changed concurrently.',
      'ADMIN',
      v_name
    );
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The copy target could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The recipe copy could not be applied safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_core.rmvp_02a_finish_import_success(
  request jsonb,
  actor_id uuid,
  command_receipt_id uuid,
  import_batch_id uuid,
  event_type text,
  result_details jsonb,
  safe_operator_message text
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
    actor_id,
    command_receipt_id,
    event_type,
    'RecipeImportBatch',
    import_batch_id,
    null,
    1,
    null,
    result_details
  );
  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02A.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status',
      case
        when event_type = 'RecipeWorkbookImportReplayed'
          then 'REPLAYED_IMPORT'
        else 'COMPLETED'
      end,
    'affected_aggregate_ids',
      pg_catalog.jsonb_build_object('import_batch_id', import_batch_id),
    'new_versions', pg_catalog.jsonb_build_object('aggregate_version', 1),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'audit_event_id'
    ),
    'authoritative_readback',
      atlas_core.rmvp_02a_recipe_workbench_payload(),
    'import_result', result_details,
    'safe_operator_message', safe_operator_message,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(
    command_receipt_id,
    v_response,
    true
  );
end;
$$;

create or replace function atlas_api.apply_recipe_import(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'apply_recipe_import';
  v_payload jsonb := request -> 'payload';
  v_canonical_json text := v_payload ->> 'canonical_json';
  v_checksum text := pg_catalog.lower(
    pg_catalog.btrim(coalesce(v_payload ->> 'workbook_checksum', ''))
  );
  v_calculated_checksum text;
  v_document jsonb;
  v_rows jsonb;
  v_source_system constant text := 'OPS_V1_RECIPE_WORKBOOK';
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_existing atlas_legacy.import_batches%rowtype;
  v_batch_id uuid := gen_random_uuid();
  v_source_counts jsonb;
  v_target_counts jsonb;
  v_mapping_counts jsonb;
  v_operation_counts jsonb;
  v_reconciliation jsonb;
  v_result jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_errors jsonb := '[]'::jsonb;
  v_total_source_count integer;
  v_inserted_count integer := 0;
  v_updated_count integer := 0;
  v_skipped_count integer := 0;
  v_row_count integer := 0;
  v_row record;
  v_dish atlas_admin.dishes%rowtype;
  v_dish_id uuid;
  v_recipe atlas_admin.recipes%rowtype;
  v_recipe_id uuid;
  v_predecessor_id uuid;
  v_recipe_version_id uuid;
  v_next_number integer;
  v_composition jsonb;
  v_changed boolean;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_canonical_json is null
     or v_checksum !~ '^[0-9a-f]{64}$'
     or pg_catalog.length(v_canonical_json) > 2000000
     or pg_catalog.btrim(coalesce(request ->> 'reason_note', '')) = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Canonical workbook rows, checksum, and import reason are required.',
      'ADMIN',
      v_name
    );
  end if;
  begin
    v_document := v_canonical_json::jsonb;
  exception when others then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The canonical workbook payload is not valid JSON.',
      'ADMIN',
      v_name
    );
  end;
  v_calculated_checksum := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(v_canonical_json, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
  if v_calculated_checksum <> v_checksum then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The workbook checksum does not match the canonical rows.',
      'ADMIN',
      v_name
    );
  end if;
  v_rows := v_document -> 'rows';
  if v_rows is null
     or pg_catalog.jsonb_typeof(v_rows) <> 'array'
     or pg_catalog.jsonb_array_length(v_rows) = 0
     or pg_catalog.jsonb_array_length(v_rows) > 5000 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The workbook must contain between 1 and 5000 canonical BOM rows.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.import',
    'recipe-import:' || v_checksum
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select * into v_existing
  from atlas_legacy.import_batches
  where source_system = v_source_system
    and snapshot_id = v_checksum
  for key share;
  if found then
    if v_existing.snapshot_checksum <> v_checksum then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'CONFLICT',
          'The import identity was already used with different content.',
          'ADMIN',
          v_name
        ),
        false
      );
    end if;
    if v_existing.import_status = 'REJECTED' then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'VALIDATION_FAILED',
          'This identical workbook was already rejected. Correct the workbook before retrying.',
          'ADMIN',
          v_name,
          false,
          v_existing.validation_errors,
          v_existing.missing_references
        ),
        false
      );
    end if;
    v_result := coalesce(v_existing.result_payload, '{}'::jsonb)
      || pg_catalog.jsonb_build_object(
        'rerun', true,
        'operation_counts',
        pg_catalog.jsonb_build_object(
          'inserted', 0,
          'updated', 0,
          'skipped', (
            select coalesce(pg_catalog.sum(value::integer), 0)
            from pg_catalog.jsonb_each_text(v_existing.source_counts)
          ),
          'rejected', 0
        )
      );
    return atlas_core.rmvp_02a_finish_import_success(
      request,
      v_actor_id,
      v_receipt_id,
      v_existing.import_batch_id,
      'RecipeWorkbookImportReplayed',
      v_result,
      'Identical reviewed workbook replayed without duplicate writes.'
    );
  end if;

  v_source_counts := pg_catalog.jsonb_build_object(
    'dishes', (
      select count(distinct pg_catalog.lower(
        pg_catalog.btrim(item ->> 'dish_code')
      ))
      from pg_catalog.jsonb_array_elements(v_rows) item
    ),
    'recipes', (
      select count(*)
      from (
        select
          pg_catalog.lower(pg_catalog.btrim(item ->> 'dish_code')),
          item ->> 'school_type_id'
        from pg_catalog.jsonb_array_elements(v_rows) item
        group by 1, 2
      ) scopes
    ),
    'recipe_versions', (
      select count(*)
      from (
        select
          pg_catalog.lower(pg_catalog.btrim(item ->> 'dish_code')),
          item ->> 'school_type_id'
        from pg_catalog.jsonb_array_elements(v_rows) item
        group by 1, 2
      ) scopes
    ),
    'recipe_lines', pg_catalog.jsonb_array_length(v_rows)
  );
  select coalesce(pg_catalog.sum(value::integer), 0)
  into v_total_source_count
  from pg_catalog.jsonb_each_text(v_source_counts);

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_rows) item
    where pg_catalog.jsonb_typeof(item) <> 'object'
      or pg_catalog.btrim(coalesce(item ->> 'legacy_line_id', '')) = ''
      or pg_catalog.btrim(coalesce(item ->> 'dish_legacy_id', '')) = ''
      or pg_catalog.btrim(coalesce(item ->> 'recipe_legacy_id', '')) = ''
      or pg_catalog.btrim(coalesce(item ->> 'dish_code', '')) = ''
      or pg_catalog.btrim(coalesce(item ->> 'dish_name', '')) = ''
      or atlas_core.pa_05b_safe_bigint(
        item ->> 'basis_portions'
      ) is null
      or atlas_core.pa_05b_safe_bigint(
        item ->> 'basis_portions'
      ) <= 0
      or atlas_core.pa_05b_safe_uuid(item ->> 'ingredient_id') is null
      or atlas_core.pa_05b_safe_uuid(item ->> 'unit_id') is null
      or atlas_core.pa_05b_safe_numeric(
        item ->> 'quantity_per_basis'
      ) is null
      or atlas_core.pa_05b_safe_numeric(
        item ->> 'quantity_per_basis'
      ) <= 0
      or (
        item ? 'requires_need_generation'
        and pg_catalog.lower(
          coalesce(item ->> 'requires_need_generation', '')
        ) not in ('true', 'false')
      )
      or (
        item ? 'school_type_id'
        and item ->> 'school_type_id' is not null
        and atlas_core.pa_05b_safe_uuid(
          item ->> 'school_type_id'
        ) is null
      )
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'rows',
        'message',
        'Each row requires legacy keys, Dish identity, positive basis and quantity, Ingredient, and Unit.'
      )
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_rows) item
    group by item ->> 'legacy_line_id'
    having count(*) > 1
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'legacy_line_id',
        'message', 'Workbook line identities must be unique.'
      )
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_rows) item
    group by
      pg_catalog.lower(pg_catalog.btrim(item ->> 'dish_code')),
      item ->> 'school_type_id',
      item ->> 'ingredient_id'
    having count(*) > 1
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'rows',
        'message',
        'A Recipe scope may contain only one contribution for an Ingredient.'
      )
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_rows) item
    group by
      pg_catalog.lower(pg_catalog.btrim(item ->> 'dish_code')),
      item ->> 'school_type_id'
    having count(distinct item ->> 'basis_portions') > 1
      or count(distinct pg_catalog.btrim(item ->> 'dish_name')) > 1
      or count(distinct item ->> 'dish_legacy_id') > 1
      or count(distinct item ->> 'recipe_legacy_id') > 1
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'rows',
        'message',
        'Dish identity, Recipe identity, name, and basis must be consistent within each scope.'
      )
    );
  end if;
  select coalesce(
    pg_catalog.jsonb_agg(error_row order by error_row::text),
    '[]'::jsonb
  )
  into v_missing
  from (
    select distinct pg_catalog.jsonb_build_object(
      'object_type', 'INGREDIENT',
      'legacy_id', item ->> 'legacy_line_id',
      'missing_reference', item ->> 'ingredient_id'
    ) error_row
    from pg_catalog.jsonb_array_elements(v_rows) item
    left join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = atlas_core.pa_05b_safe_uuid(
        item ->> 'ingredient_id'
      )
    where ingredient.ingredient_id is null
      or ingredient.ingredient_status <> 'ACTIVE'
    union all
    select distinct pg_catalog.jsonb_build_object(
      'object_type', 'UNIT',
      'legacy_id', item ->> 'legacy_line_id',
      'missing_reference', item ->> 'unit_id'
    )
    from pg_catalog.jsonb_array_elements(v_rows) item
    left join atlas_admin.units unit
      on unit.unit_id = atlas_core.pa_05b_safe_uuid(item ->> 'unit_id')
    where unit.unit_id is null or unit.unit_status <> 'ACTIVE'
    union all
    select distinct pg_catalog.jsonb_build_object(
      'object_type', 'SCHOOL_TYPE',
      'legacy_id', item ->> 'recipe_legacy_id',
      'missing_reference', item ->> 'school_type_id'
    )
    from pg_catalog.jsonb_array_elements(v_rows) item
    left join atlas_admin.school_types school_type
      on school_type.school_type_id = atlas_core.pa_05b_safe_uuid(
        item ->> 'school_type_id'
      )
    where item ->> 'school_type_id' is not null
      and (
        school_type.school_type_id is null
        or school_type.school_type_status <> 'ACTIVE'
      )
  ) errors;
  if exists (
    select 1
    from (
      select distinct
        pg_catalog.lower(pg_catalog.btrim(item ->> 'dish_code'))
          as dish_code,
        atlas_core.pa_05b_safe_uuid(item ->> 'school_type_id')
          as school_type_id
      from pg_catalog.jsonb_array_elements(v_rows) item
    ) scope
    join atlas_admin.dishes dish on dish.dish_code = scope.dish_code
    left join atlas_admin.recipes recipe
      on recipe.dish_id = dish.dish_id
     and recipe.school_type_id is not distinct from scope.school_type_id
     and recipe.recipe_status = 'ACTIVE'
    where dish.dish_status = 'INACTIVE'
      or exists (
        select 1
        from atlas_admin.recipe_versions version
        where version.recipe_id = recipe.recipe_id
          and version.recipe_version_status in ('DRAFT', 'VALIDATED')
      )
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'rows',
        'message',
        'An inactive Dish or unfinished target Recipe blocks import; released history is never overwritten.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0
     or pg_catalog.jsonb_array_length(v_missing) > 0 then
    v_operation_counts := pg_catalog.jsonb_build_object(
      'inserted', 0,
      'updated', 0,
      'skipped', 0,
      'rejected', v_total_source_count
    );
    v_result := pg_catalog.jsonb_build_object(
      'success', false,
      'error_code', 'WORKBOOK_REJECTED',
      'source_counts', v_source_counts,
      'operation_counts', v_operation_counts,
      'missing_references', v_missing,
      'validation_errors', v_errors,
      'reconciliation', pg_catalog.jsonb_build_object('passed', false),
      'rerun', false
    );
    insert into atlas_legacy.import_batches (
      import_batch_id,
      source_system,
      snapshot_id,
      snapshot_checksum,
      exported_at,
      import_status,
      source_counts,
      operation_counts,
      missing_references,
      validation_errors,
      reconciliation,
      result_payload,
      completed_at
    ) values (
      v_batch_id,
      v_source_system,
      v_checksum,
      v_checksum,
      atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at'),
      'REJECTED',
      v_source_counts,
      v_operation_counts,
      v_missing,
      v_errors,
      pg_catalog.jsonb_build_object('passed', false),
      v_result,
      pg_catalog.transaction_timestamp()
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The workbook failed authoritative reference or value validation.',
        'ADMIN',
        v_name,
        false,
        v_errors,
        v_missing
      ),
      false
    );
  end if;

  insert into atlas_legacy.import_batches (
    import_batch_id,
    source_system,
    snapshot_id,
    snapshot_checksum,
    exported_at,
    import_status,
    source_counts,
    reconciliation,
    completed_at
  ) values (
    v_batch_id,
    v_source_system,
    v_checksum,
    v_checksum,
    atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at'),
    'COMPLETED',
    v_source_counts,
    pg_catalog.jsonb_build_object('passed', false, 'pending', true),
    pg_catalog.transaction_timestamp()
  );

  for v_row in
    select
      item ->> 'dish_legacy_id' as dish_legacy_id,
      pg_catalog.lower(pg_catalog.btrim(item ->> 'dish_code')) as dish_code,
      pg_catalog.btrim(item ->> 'dish_name') as dish_name,
      nullif(pg_catalog.btrim(item ->> 'dish_category'), '')
        as dish_category,
      nullif(pg_catalog.btrim(item ->> 'operational_notes'), '')
        as operational_notes,
      case pg_catalog.lower(item ->> 'requires_need_generation')
        when 'false' then false
        else true
      end as requires_need_generation
    from pg_catalog.jsonb_array_elements(v_rows) item
    group by 1, 2, 3, 4, 5, 6
    order by 2
  loop
    select * into v_dish
    from atlas_admin.dishes
    where dish_code = v_row.dish_code
    for update;
    if not found then
      insert into atlas_admin.dishes (
        dish_code,
        dish_name,
        dish_category,
        operational_notes,
        dish_status,
        display_order,
        requires_need_generation
      ) values (
        v_row.dish_code,
        v_row.dish_name,
        v_row.dish_category,
        v_row.operational_notes,
        'DRAFT',
        0,
        v_row.requires_need_generation
      )
      returning * into v_dish;
      v_inserted_count := v_inserted_count + 1;
    else
      v_changed := v_dish.dish_status = 'DRAFT' and (
        v_dish.dish_name,
        v_dish.dish_category,
        v_dish.operational_notes,
        v_dish.requires_need_generation
      ) is distinct from (
        v_row.dish_name,
        v_row.dish_category,
        v_row.operational_notes,
        v_row.requires_need_generation
      );
      if v_changed then
        update atlas_admin.dishes
        set dish_name = v_row.dish_name,
            dish_category = v_row.dish_category,
            operational_notes = v_row.operational_notes,
            requires_need_generation = v_row.requires_need_generation,
            version = version + 1,
            updated_at = pg_catalog.transaction_timestamp()
        where dish_id = v_dish.dish_id
        returning * into v_dish;
        v_updated_count := v_updated_count + 1;
      else
        v_skipped_count := v_skipped_count + 1;
      end if;
    end if;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id,
      source_system,
      object_type,
      legacy_id,
      dish_id
    ) values (
      v_batch_id,
      v_source_system,
      'DISH',
      v_row.dish_legacy_id,
      v_dish.dish_id
    )
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      dish_id = excluded.dish_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  for v_row in
    select
      item ->> 'dish_legacy_id' as dish_legacy_id,
      item ->> 'recipe_legacy_id' as recipe_legacy_id,
      atlas_core.pa_05b_safe_uuid(item ->> 'school_type_id')
        as school_type_id,
      atlas_core.pa_05b_safe_bigint(item ->> 'basis_portions')::integer
        as basis_portions
    from pg_catalog.jsonb_array_elements(v_rows) item
    group by 1, 2, 3, 4
    order by 1, 3 nulls first
  loop
    select mapping.dish_id into v_dish_id
    from atlas_legacy.master_data_mappings mapping
    where mapping.source_system = v_source_system
      and mapping.object_type = 'DISH'
      and mapping.legacy_id = v_row.dish_legacy_id;
    select * into v_recipe
    from atlas_admin.recipes recipe
    where recipe.dish_id = v_dish_id
      and recipe.school_type_id is not distinct from v_row.school_type_id
      and recipe.recipe_status = 'ACTIVE'
    for update;
    if not found then
      insert into atlas_admin.recipes (
        dish_id,
        school_type_id,
        recipe_status
      ) values (
        v_dish_id,
        v_row.school_type_id,
        'ACTIVE'
      )
      returning * into v_recipe;
      v_inserted_count := v_inserted_count + 1;
    else
      v_skipped_count := v_skipped_count + 1;
    end if;
    v_recipe_id := v_recipe.recipe_id;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id,
      source_system,
      object_type,
      legacy_id,
      recipe_id
    ) values (
      v_batch_id,
      v_source_system,
      'RECIPE',
      v_row.recipe_legacy_id,
      v_recipe_id
    )
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      recipe_id = excluded.recipe_id,
      updated_at = pg_catalog.transaction_timestamp();

    select version.recipe_version_id
    into v_predecessor_id
    from atlas_admin.recipe_versions version
    where version.recipe_id = v_recipe_id
      and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
    order by version.version_number desc
    limit 1;
    if v_predecessor_id is null then
      select version.recipe_version_id
      into v_predecessor_id
      from atlas_admin.recipe_versions version
      where version.recipe_id = v_recipe_id
        and version.recipe_version_status = 'LOCKED'
      order by version.version_number desc
      limit 1;
    end if;
    select coalesce(pg_catalog.max(version_number), 0) + 1
    into v_next_number
    from atlas_admin.recipe_versions
    where recipe_id = v_recipe_id;

    with source_lines as (
      select
        item ->> 'legacy_line_id' as legacy_line_id,
        atlas_core.pa_05b_safe_uuid(item ->> 'ingredient_id')
          as ingredient_id,
        atlas_core.pa_05b_safe_numeric(item ->> 'quantity_per_basis')
          as quantity_per_basis,
        atlas_core.pa_05b_safe_uuid(item ->> 'unit_id') as unit_id,
        nullif(pg_catalog.btrim(item ->> 'operational_note'), '')
          as operational_note
      from pg_catalog.jsonb_array_elements(v_rows) item
      where item ->> 'recipe_legacy_id' = v_row.recipe_legacy_id
    ),
    target_lines as (
      select
        revision.recipe_line_revision_id,
        revision.recipe_line_id,
        revision.ingredient_id,
        revision.unit_id,
        revision.operational_note,
        line.line_code
      from atlas_admin.recipe_line_revisions revision
      join atlas_admin.recipe_lines line
        on line.recipe_line_id = revision.recipe_line_id
      where revision.recipe_version_id = v_predecessor_id
        and revision.line_disposition = 'PRESENT'
    ),
    resolved as (
      select
        source.legacy_line_id,
        coalesce(
          mapped.recipe_line_id,
          target_by_ingredient.recipe_line_id,
          gen_random_uuid()
        ) as recipe_line_id,
        coalesce(
          target_by_mapping.recipe_line_revision_id,
          target_by_ingredient.recipe_line_revision_id
        ) as predecessor_recipe_line_revision_id,
        source.ingredient_id,
        source.quantity_per_basis,
        source.unit_id,
        'PRESENT'::text as line_disposition,
        source.operational_note,
        coalesce(
          target_by_mapping.line_code,
          target_by_ingredient.line_code
        ) as line_code
      from source_lines source
      left join atlas_legacy.master_data_mappings mapped
        on mapped.source_system = v_source_system
       and mapped.object_type = 'RECIPE_LINE'
       and mapped.legacy_id = source.legacy_line_id
      left join target_lines target_by_mapping
        on target_by_mapping.recipe_line_id = mapped.recipe_line_id
      left join target_lines target_by_ingredient
        on target_by_ingredient.ingredient_id = source.ingredient_id
       and mapped.recipe_line_id is null
    ),
    removed as (
      select
        null::text as legacy_line_id,
        target.recipe_line_id,
        target.recipe_line_revision_id
          as predecessor_recipe_line_revision_id,
        target.ingredient_id,
        0::numeric as quantity_per_basis,
        target.unit_id,
        'REMOVED'::text as line_disposition,
        target.operational_note,
        target.line_code
      from target_lines target
      where not exists (
        select 1
        from resolved source
        where source.recipe_line_id = target.recipe_line_id
      )
    )
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'recipe_line_id', composition.recipe_line_id,
          'predecessor_recipe_line_revision_id',
            composition.predecessor_recipe_line_revision_id,
          'ingredient_id', composition.ingredient_id,
          'quantity_per_basis', composition.quantity_per_basis,
          'unit_id', composition.unit_id,
          'line_disposition', composition.line_disposition,
          'operational_note', composition.operational_note,
          'line_code', composition.line_code,
          'legacy_line_id', composition.legacy_line_id
        )
        order by composition.line_disposition, composition.ingredient_id
      ),
      '[]'::jsonb
    )
    into v_composition
    from (
      select * from resolved
      union all
      select * from removed
    ) composition;

    if (
      select count(distinct item ->> 'recipe_line_id')
      from pg_catalog.jsonb_array_elements(v_composition) item
    ) <> pg_catalog.jsonb_array_length(v_composition) then
      raise exception using
        errcode = '23514',
        message = 'Workbook stable-line mapping is ambiguous.';
    end if;
    insert into atlas_admin.recipe_lines (
      recipe_line_id,
      recipe_id,
      line_code
    )
    select
      atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id'),
      v_recipe_id,
      nullif(item ->> 'line_code', '')
    from pg_catalog.jsonb_array_elements(v_composition) item
    where not exists (
      select 1
      from atlas_admin.recipe_lines line
      where line.recipe_line_id = atlas_core.pa_05b_safe_uuid(
        item ->> 'recipe_line_id'
      )
    );
    get diagnostics v_row_count = row_count;
    v_inserted_count := v_inserted_count + v_row_count;

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
      v_row.basis_portions,
      'DRAFT',
      v_actor_id,
      v_composition,
      pg_catalog.jsonb_build_object(
        'source_kind', 'WORKBOOK_IMPORT',
        'source_system', v_source_system,
        'import_batch_id', v_batch_id,
        'workbook_checksum', v_checksum,
        'recipe_legacy_id', v_row.recipe_legacy_id,
        'reason_note', request ->> 'reason_note'
      )
    )
    returning recipe_version_id into v_recipe_version_id;
    v_inserted_count := v_inserted_count + 1;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id,
      source_system,
      object_type,
      legacy_id,
      recipe_version_id
    ) values (
      v_batch_id,
      v_source_system,
      'RECIPE_VERSION',
      v_row.recipe_legacy_id || ':' || v_checksum,
      v_recipe_version_id
    );
    insert into atlas_legacy.master_data_mappings (
      import_batch_id,
      source_system,
      object_type,
      legacy_id,
      recipe_line_id
    )
    select
      v_batch_id,
      v_source_system,
      'RECIPE_LINE',
      item ->> 'legacy_line_id',
      atlas_core.pa_05b_safe_uuid(item ->> 'recipe_line_id')
    from pg_catalog.jsonb_array_elements(v_composition) item
    where nullif(item ->> 'legacy_line_id', '') is not null
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      recipe_line_id = excluded.recipe_line_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  select coalesce(pg_catalog.jsonb_object_agg(object_type, item_count), '{}')
  into v_mapping_counts
  from (
    select object_type, count(*) item_count
    from atlas_legacy.master_data_mappings
    where import_batch_id = v_batch_id
    group by object_type
    order by object_type
  ) mapping_summary;
  v_target_counts := pg_catalog.jsonb_build_object(
    'dishes', coalesce((v_mapping_counts ->> 'DISH')::integer, 0),
    'recipes', coalesce((v_mapping_counts ->> 'RECIPE')::integer, 0),
    'recipe_versions',
      coalesce((v_mapping_counts ->> 'RECIPE_VERSION')::integer, 0),
    'recipe_lines',
      coalesce((v_mapping_counts ->> 'RECIPE_LINE')::integer, 0)
  );
  v_reconciliation := pg_catalog.jsonb_build_object(
    'passed', v_source_counts = v_target_counts,
    'source_counts', v_source_counts,
    'target_counts', v_target_counts
  );
  if v_source_counts <> v_target_counts then
    raise exception using
      errcode = '23514',
      message = 'Recipe workbook reconciliation failed; target writes were rolled back.';
  end if;
  v_operation_counts := pg_catalog.jsonb_build_object(
    'inserted', v_inserted_count,
    'updated', v_updated_count,
    'skipped', v_skipped_count,
    'rejected', 0
  );
  v_result := pg_catalog.jsonb_build_object(
    'success', true,
    'import_batch_id', v_batch_id,
    'source_counts', v_source_counts,
    'target_counts', v_target_counts,
    'mapping_counts', v_mapping_counts,
    'operation_counts', v_operation_counts,
    'missing_references', '[]'::jsonb,
    'validation_errors', '[]'::jsonb,
    'reconciliation', v_reconciliation,
    'lifecycle_interpretation',
      'OPS v1 workbook rows create Atlas DRAFT Recipe Versions only.',
    'rerun', false
  );
  update atlas_legacy.import_batches
  set target_counts = v_target_counts,
      mapping_counts = v_mapping_counts,
      operation_counts = v_operation_counts,
      reconciliation = v_reconciliation,
      result_payload = v_result,
      completed_at = pg_catalog.transaction_timestamp()
  where import_batch_id = v_batch_id;
  return atlas_core.rmvp_02a_finish_import_success(
    request,
    v_actor_id,
    v_receipt_id,
    v_batch_id,
    'RecipeWorkbookImported',
    v_result,
    'Reviewed workbook imported atomically as Atlas drafts.'
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The workbook targets could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The workbook could not be applied safely; no partial target writes were committed.',
      'ADMIN',
      v_name
    );
end;
$$;

grant usage on schema
  atlas_core,
  atlas_admin,
  atlas_audit,
  atlas_api,
  atlas_legacy,
  extensions
to atlas_master_data_command_runtime;

grant execute on function
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_numeric(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(
    jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint
  ),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(
    jsonb, uuid, text, text, text, uuid, uuid, uuid
  ),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean),
  atlas_core.rmvp_01_record_change(
    jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb
  ),
  atlas_core.rmvp_02a_validate_command_request(jsonb, text),
  atlas_core.rmvp_02a_prepare_command(jsonb, text, text, text),
  atlas_core.rmvp_02a_recipe_version_composition(uuid),
  atlas_core.rmvp_02a_recipe_workbench_payload(),
  atlas_core.rmvp_02a_finish_success(
    jsonb, uuid, uuid, text, text, uuid, bigint, bigint,
    jsonb, jsonb, text, jsonb
  ),
  atlas_core.rmvp_02a_finish_import_success(
    jsonb, uuid, uuid, uuid, text, jsonb, text
  ),
  extensions.digest(bytea, text)
to atlas_master_data_command_runtime;

grant select on
  atlas_core.actors,
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes,
  atlas_core.command_receipts,
  atlas_admin.school_types,
  atlas_admin.units,
  atlas_admin.ingredients,
  atlas_admin.dishes,
  atlas_admin.recipes,
  atlas_admin.recipe_versions,
  atlas_admin.recipe_lines,
  atlas_admin.recipe_line_revisions,
  atlas_legacy.import_batches,
  atlas_legacy.master_data_mappings
to atlas_master_data_command_runtime;

grant insert, update on atlas_core.command_receipts
  to atlas_master_data_command_runtime;

grant insert (
  dish_code,
  dish_name,
  dish_category,
  operational_notes,
  dish_status,
  display_order,
  requires_need_generation
) on atlas_admin.dishes to atlas_master_data_command_runtime;
grant update (
  dish_name,
  dish_category,
  operational_notes,
  dish_status,
  display_order,
  requires_need_generation,
  version,
  updated_at
) on atlas_admin.dishes to atlas_master_data_command_runtime;

grant insert (
  dish_id,
  school_type_id,
  recipe_status
) on atlas_admin.recipes to atlas_master_data_command_runtime;
grant update (
  recipe_status,
  version,
  updated_at
) on atlas_admin.recipes to atlas_master_data_command_runtime;

grant insert (
  recipe_id,
  version_number,
  predecessor_recipe_version_id,
  basis_portions,
  recipe_version_status,
  created_by_actor_id,
  draft_composition,
  source_evidence
) on atlas_admin.recipe_versions to atlas_master_data_command_runtime;
grant update (
  basis_portions,
  recipe_version_status,
  validated_by_actor_id,
  validated_at,
  released_by_actor_id,
  released_at,
  locked_by_actor_id,
  locked_at,
  draft_composition,
  source_evidence,
  version
) on atlas_admin.recipe_versions to atlas_master_data_command_runtime;

grant insert (
  recipe_line_id,
  recipe_id,
  line_code
) on atlas_admin.recipe_lines to atlas_master_data_command_runtime;
grant insert (
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
) on atlas_admin.recipe_line_revisions
to atlas_master_data_command_runtime;

grant insert (
  import_batch_id,
  source_system,
  snapshot_id,
  snapshot_checksum,
  exported_at,
  import_status,
  source_counts,
  target_counts,
  mapping_counts,
  operation_counts,
  duplicate_references,
  missing_references,
  validation_errors,
  reconciliation,
  result_payload,
  completed_at
) on atlas_legacy.import_batches to atlas_master_data_command_runtime;
grant update (
  target_counts,
  mapping_counts,
  operation_counts,
  missing_references,
  validation_errors,
  reconciliation,
  result_payload,
  completed_at
) on atlas_legacy.import_batches to atlas_master_data_command_runtime;
grant insert (
  import_batch_id,
  source_system,
  object_type,
  legacy_id,
  dish_id,
  recipe_id,
  recipe_version_id,
  recipe_line_id,
  recipe_line_revision_id
) on atlas_legacy.master_data_mappings
to atlas_master_data_command_runtime;
grant update (
  import_batch_id,
  dish_id,
  recipe_id,
  recipe_version_id,
  recipe_line_id,
  recipe_line_revision_id,
  updated_at
) on atlas_legacy.master_data_mappings
to atlas_master_data_command_runtime;

grant insert on
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_master_data_command_runtime;
grant select (domain_event_id) on atlas_audit.domain_events
  to atlas_master_data_command_runtime;
grant select (audit_event_id) on atlas_audit.audit_events
  to atlas_master_data_command_runtime;

create policy rmvp_02a_command_select on atlas_admin.dishes
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02a_command_insert on atlas_admin.dishes
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02a_command_update on atlas_admin.dishes
  for update to atlas_master_data_command_runtime
  using (true) with check (true);
create policy rmvp_02a_command_select on atlas_admin.recipes
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02a_command_insert on atlas_admin.recipes
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02a_command_update on atlas_admin.recipes
  for update to atlas_master_data_command_runtime
  using (true) with check (true);
create policy rmvp_02a_command_select on atlas_admin.recipe_versions
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02a_command_insert on atlas_admin.recipe_versions
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02a_command_update on atlas_admin.recipe_versions
  for update to atlas_master_data_command_runtime
  using (true) with check (true);
create policy rmvp_02a_command_select on atlas_admin.recipe_lines
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02a_command_insert on atlas_admin.recipe_lines
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02a_command_select
  on atlas_admin.recipe_line_revisions
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02a_command_insert
  on atlas_admin.recipe_line_revisions
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02a_command_select on atlas_legacy.import_batches
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02a_command_insert on atlas_legacy.import_batches
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02a_command_update on atlas_legacy.import_batches
  for update to atlas_master_data_command_runtime
  using (true) with check (true);
create policy rmvp_02a_command_select on atlas_legacy.master_data_mappings
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02a_command_insert on atlas_legacy.master_data_mappings
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02a_command_update on atlas_legacy.master_data_mappings
  for update to atlas_master_data_command_runtime
  using (true) with check (true);
create policy rmvp_02a_command_audit_insert on atlas_audit.domain_events
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02a_command_audit_select on atlas_audit.domain_events
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_02a_command_audit_insert on atlas_audit.audit_events
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_02a_command_audit_select on atlas_audit.audit_events
  for select to atlas_master_data_command_runtime using (true);

grant select on
  atlas_admin.dishes,
  atlas_admin.recipes,
  atlas_admin.recipe_versions,
  atlas_admin.recipe_lines,
  atlas_admin.recipe_line_revisions
to atlas_read_runtime;
create policy rmvp_02a_read_select on atlas_admin.dishes
  for select to atlas_read_runtime using (true);
create policy rmvp_02a_read_select on atlas_admin.recipes
  for select to atlas_read_runtime using (true);
create policy rmvp_02a_read_select on atlas_admin.recipe_versions
  for select to atlas_read_runtime using (true);
create policy rmvp_02a_read_select on atlas_admin.recipe_lines
  for select to atlas_read_runtime using (true);
create policy rmvp_02a_read_select on atlas_admin.recipe_line_revisions
  for select to atlas_read_runtime using (true);

alter function atlas_core.rmvp_02a_read_error(
  jsonb, text, text, text, jsonb
) owner to atlas_owner;
alter function atlas_core.rmvp_02a_validate_read_request(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_02a_validate_command_request(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_02a_prepare_command(
  jsonb, text, text, text
) owner to atlas_owner;
alter function atlas_core.rmvp_02a_recipe_version_composition(uuid)
  owner to atlas_owner;
alter function atlas_core.rmvp_02a_recipe_workbench_payload()
  owner to atlas_owner;
alter function atlas_core.rmvp_02a_finish_success(
  jsonb, uuid, uuid, text, text, uuid, bigint, bigint,
  jsonb, jsonb, text, jsonb
) owner to atlas_owner;
alter function atlas_core.rmvp_02a_finish_import_success(
  jsonb, uuid, uuid, uuid, text, jsonb, text
) owner to atlas_owner;

grant execute on function
  atlas_core.rmvp_02a_read_error(jsonb, text, text, text, jsonb),
  atlas_core.rmvp_02a_validate_read_request(jsonb, text),
  atlas_core.rmvp_02a_recipe_version_composition(uuid),
  atlas_core.rmvp_02a_recipe_workbench_payload()
to atlas_read_runtime;
grant execute on function
  atlas_core.rmvp_01_authorize_global(jsonb, text, text)
to atlas_read_runtime;

grant atlas_master_data_command_runtime, atlas_read_runtime
  to postgres with set true;
grant create on schema atlas_api to
  atlas_master_data_command_runtime,
  atlas_read_runtime;
alter function atlas_api.get_dish_recipe_workbench(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.create_dish(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.update_dish(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.set_dish_lifecycle(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.set_recipe_lifecycle(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.create_recipe_draft(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.create_recipe_successor_version(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.replace_recipe_draft_composition(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.validate_recipe_version(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.release_recipe_version_for_planning(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.copy_recipe_version(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.apply_recipe_import(jsonb)
  owner to atlas_master_data_command_runtime;
revoke create on schema atlas_api from
  atlas_master_data_command_runtime,
  atlas_read_runtime;

revoke execute on function
  atlas_core.rmvp_02a_read_error(jsonb, text, text, text, jsonb),
  atlas_core.rmvp_02a_validate_read_request(jsonb, text),
  atlas_core.rmvp_02a_validate_command_request(jsonb, text),
  atlas_core.rmvp_02a_prepare_command(jsonb, text, text, text),
  atlas_core.rmvp_02a_recipe_version_composition(uuid),
  atlas_core.rmvp_02a_recipe_workbench_payload(),
  atlas_core.rmvp_02a_finish_success(
    jsonb, uuid, uuid, text, text, uuid, bigint, bigint,
    jsonb, jsonb, text, jsonb
  ),
  atlas_core.rmvp_02a_finish_import_success(
    jsonb, uuid, uuid, uuid, text, jsonb, text
  )
from public, anon, authenticated, service_role;

revoke execute on function
  atlas_api.get_dish_recipe_workbench(jsonb),
  atlas_api.create_dish(jsonb),
  atlas_api.update_dish(jsonb),
  atlas_api.set_dish_lifecycle(jsonb),
  atlas_api.set_recipe_lifecycle(jsonb),
  atlas_api.create_recipe_draft(jsonb),
  atlas_api.create_recipe_successor_version(jsonb),
  atlas_api.replace_recipe_draft_composition(jsonb),
  atlas_api.validate_recipe_version(jsonb),
  atlas_api.release_recipe_version_for_planning(jsonb),
  atlas_api.copy_recipe_version(jsonb),
  atlas_api.apply_recipe_import(jsonb)
from public, anon, service_role;
grant execute on function
  atlas_api.get_dish_recipe_workbench(jsonb),
  atlas_api.create_dish(jsonb),
  atlas_api.update_dish(jsonb),
  atlas_api.set_dish_lifecycle(jsonb),
  atlas_api.set_recipe_lifecycle(jsonb),
  atlas_api.create_recipe_draft(jsonb),
  atlas_api.create_recipe_successor_version(jsonb),
  atlas_api.replace_recipe_draft_composition(jsonb),
  atlas_api.validate_recipe_version(jsonb),
  atlas_api.release_recipe_version_for_planning(jsonb),
  atlas_api.copy_recipe_version(jsonb),
  atlas_api.apply_recipe_import(jsonb)
to authenticated;

comment on function atlas_api.get_dish_recipe_workbench(jsonb) is
  'RMVP-02A authorized global read for Dish, Recipe scope, version history, BOM composition, and workbook references.';
comment on function atlas_api.create_dish(jsonb) is
  'RMVP-02A command creating one complete DRAFT or ACTIVE Dish.';
comment on function atlas_api.update_dish(jsonb) is
  'RMVP-02A versioned Dish details command; lifecycle is separate.';
comment on function atlas_api.set_dish_lifecycle(jsonb) is
  'RMVP-02A versioned Dish activate/deactivate command; Dish rows are never deleted.';
comment on function atlas_api.set_recipe_lifecycle(jsonb) is
  'RMVP-02A versioned Recipe-root activate/deactivate command.';
comment on function atlas_api.create_recipe_draft(jsonb) is
  'RMVP-02A command creating a scoped Recipe root when needed and one empty DRAFT Recipe Version.';
comment on function atlas_api.create_recipe_successor_version(jsonb) is
  'RMVP-02A command creating a DRAFT successor with explicit inherited composition.';
comment on function atlas_api.replace_recipe_draft_composition(jsonb) is
  'RMVP-02A atomic full replacement of one mutable DRAFT basis and BOM composition.';
comment on function atlas_api.validate_recipe_version(jsonb) is
  'RMVP-02A command materializing stable BOM lines and immutable line revisions while transitioning DRAFT to VALIDATED.';
comment on function atlas_api.release_recipe_version_for_planning(jsonb) is
  'RMVP-02A command releasing a VALIDATED version for future Planning only; the existing lifecycle guard locks the prior release.';
comment on function atlas_api.copy_recipe_version(jsonb) is
  'RMVP-02A authoritative copy command producing a new target DRAFT without overwriting any existing version.';
comment on function atlas_api.apply_recipe_import(jsonb) is
  'RMVP-02A reviewed, checksum-bound, atomic, idempotent OPS v1 workbook import into DRAFT Recipe Versions with typed reconciliation.';

comment on schema atlas_api is
  'Function-only Atlas Data API boundary; includes reviewed operational, RMVP-01 master-data, and RMVP-02A Recipe/BOM commands and reads.';

revoke atlas_master_data_command_runtime, atlas_read_runtime from postgres;
