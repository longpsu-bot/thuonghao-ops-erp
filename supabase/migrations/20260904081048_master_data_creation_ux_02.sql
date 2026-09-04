-- MASTER-DATA-CREATION-UX-02: bounded creation contract corrections.
-- Preserve all request bytes, hashes, authorization, receipts, grants, and RLS.
-- No table/data changes; rollback requires forward restoration of these functions.

create or replace function atlas_core.rmvp_01_validate_command_request(
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
      command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'request',
          'message',
          'A JSON object is required.'
        )
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-01.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'contract_version',
        'message',
        'Use RMVP-01.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'command_id',
        'message',
        'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'correlation_id',
        'message',
        'A valid UUID is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
     or pg_catalog.length(request ->> 'idempotency_key') > 200 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'idempotency_key',
        'message',
        'A non-empty key of at most 200 characters is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'expected_version',
        'message',
        'A positive integer version is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'requested_by_auth_subject',
        'message',
        'A valid UUID is required.'
      )
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at');
  if v_requested_at is null or v_requested_at > pg_catalog.transaction_timestamp() + interval '60 seconds' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'requested_at',
        'message',
        'A valid timestamp no more than 60 seconds ahead of the database is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = '' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'reason_code',
        'message',
        'A reason code is required.'
      )
    );
  end if;
  if not (request ? 'reason_note') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'reason_note',
        'message',
        'The reason_note field is required and may be null.'
      )
    );
  end if;
  if request -> 'payload' is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'payload',
        'message',
        'A JSON object is required.'
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
     or v_requested_at > pg_catalog.transaction_timestamp() + interval '60 seconds' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_at',
        'message', 'A valid timestamp no more than 60 seconds ahead of the database is required.'
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

create or replace function atlas_api.create_ingredient(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_ingredient';
  v_payload jsonb := request -> 'payload';
  v_code text := pg_catalog.lower(pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_code', '')));
  v_ingredient_name text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_name', ''));
  v_type_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_type_id');
  v_type_text text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_type', ''));
  v_group_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_order_group_id');
  v_group_text text := pg_catalog.btrim(coalesce(v_payload ->> 'shopping_type', ''));
  v_type atlas_admin.ingredient_types%rowtype;
  v_group atlas_admin.ingredient_order_groups%rowtype;
  v_unit_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'purchase_unit_id');
  v_order_step numeric := atlas_core.pa_05b_safe_numeric(v_payload ->> 'order_step');
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_ingredient_id uuid;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
     or (v_payload ? 'ingredient_code' and v_code = '') or v_ingredient_name = '' or v_unit_id is null
     or v_order_step is null or v_order_step <= 0
     or (not (v_payload ? 'ingredient_type_id') and v_type_text = '')
     or (not (v_payload ? 'ingredient_order_group_id') and v_group_text = '')
     or ((v_payload ? 'ingredient_type_id') and v_type_id is null)
     or ((v_payload ? 'ingredient_order_group_id') and v_group_id is null) then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'Ingredient values are incomplete or invalid.',
      'ADMIN', v_name, false,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'name, purchase unit, authoritative ingredient type, authoritative order group, and a positive order step are required; create uses expected_version 1.'
      ))
    );
  end if;

  if v_type_id is not null then
    select * into v_type from atlas_admin.ingredient_types
    where ingredient_type_id = v_type_id and ingredient_type_status = 'ACTIVE';
  else
    select * into v_type from atlas_admin.ingredient_types
    where lower(ingredient_type_name) = lower(v_type_text)
      and ingredient_type_status = 'ACTIVE';
  end if;
  if not found or (v_type_text <> '' and lower(v_type_text) <> lower(v_type.ingredient_type_name)) then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The ingredient type is not an active Atlas catalog value.',
      'ADMIN', v_name, false,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'field', 'payload.ingredient_type_id',
        'message', 'Use one active Ingredient type ID, or its exact canonical display name.'
      ))
    );
  end if;

  if v_group_id is not null then
    select * into v_group from atlas_admin.ingredient_order_groups
    where ingredient_order_group_id = v_group_id
      and ingredient_order_group_status = 'ACTIVE';
  else
    select * into v_group from atlas_admin.ingredient_order_groups
    where lower(ingredient_order_group_name) = lower(v_group_text)
      and ingredient_order_group_status = 'ACTIVE';
  end if;
  if not found or (v_group_text <> '' and lower(v_group_text) <> lower(v_group.ingredient_order_group_name)) then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The order group is not an active Atlas catalog value.',
      'ADMIN', v_name, false,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'field', 'payload.ingredient_order_group_id',
        'message', 'Use one active Ingredient order-group ID, or its exact canonical display name.'
      ))
    );
  end if;

  v_prepare := atlas_core.rmvp_01_prepare_command(
    request, v_name, 'master_data.ingredients.write', case when v_payload ? 'ingredient_code' then 'ingredient-code:' || v_code
      else 'ingredient-create' end
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  if not exists (
    select 1 from atlas_admin.units
    where unit_id = v_unit_id and unit_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED', 'The purchase unit is not active.', 'ADMIN', v_name
      ), false
    );
  end if;
  -- Generate after authorization and exact replay resolution. Random metadata
  -- never enters request hashing or the stable receipt scope.
  if not (v_payload ? 'ingredient_code') then
    v_code := 'ingredient-' || pg_catalog.gen_random_uuid()::text;
  end if;
  insert into atlas_admin.ingredients (
    ingredient_code, ingredient_name, ingredient_group, purchase_unit_id,
    ingredient_type_id, ingredient_order_group_id,
    ingredient_type, shopping_type, order_step
  ) values (
    v_code, v_ingredient_name, v_type.ingredient_type_name, v_unit_id,
    v_type.ingredient_type_id, v_group.ingredient_order_group_id,
    v_type.ingredient_type_name, v_group.ingredient_order_group_name, v_order_step
  ) returning ingredient_id into v_ingredient_id;
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'IngredientCreated',
    'Ingredient', v_ingredient_id, null, 1, null,
    pg_catalog.jsonb_build_object(
      'ingredient_code', v_code,
      'ingredient_name', v_ingredient_name,
      'ingredient_status', 'ACTIVE',
      'purchase_unit_id', v_unit_id,
      'ingredient_type_id', v_type.ingredient_type_id,
      'ingredient_type', v_type.ingredient_type_name,
      'ingredient_order_group_id', v_group.ingredient_order_group_id,
      'shopping_type', v_group.ingredient_order_group_name,
      'order_step', v_order_step
    ),
    'Ingredient created.',
    pg_catalog.jsonb_build_object('ingredient_id', v_ingredient_id)
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request, 'CONFLICT', 'The ingredient code is already in use.', 'ADMIN', v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE', 'The ingredient could not be created safely.', 'ADMIN', v_name
    );
end;
$$;

create or replace function atlas_api.create_supplier(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_supplier';
  v_payload jsonb := request -> 'payload';
  v_code text := pg_catalog.lower(pg_catalog.btrim(coalesce(v_payload ->> 'supplier_code', '')));
  v_supplier_name text := pg_catalog.btrim(coalesce(v_payload ->> 'supplier_name', ''));
  v_contact_name text := nullif(pg_catalog.btrim(coalesce(v_payload ->> 'contact_name', '')), '');
  v_contact_phone text := nullif(pg_catalog.btrim(coalesce(v_payload ->> 'contact_phone', '')), '');
  v_contact_email text := nullif(pg_catalog.btrim(coalesce(v_payload ->> 'contact_email', '')), '');
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_supplier_id uuid;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
     or (v_payload ? 'supplier_code' and v_code = '') or v_supplier_name = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Supplier values are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload',
          'message',
          'supplier_name is required; create uses expected_version 1.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request,
    v_name,
    'master_data.suppliers.write',
    case when v_payload ? 'supplier_code' then 'supplier-code:' || v_code
      else 'supplier-create' end
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  -- Generate after authorization and exact replay resolution. Random metadata
  -- never enters request hashing or the stable receipt scope.
  if not (v_payload ? 'supplier_code') then
    v_code := 'supplier-' || pg_catalog.gen_random_uuid()::text;
  end if;
  insert into atlas_admin.suppliers (
    supplier_code,
    supplier_name,
    contact_name,
    contact_phone,
    contact_email
  ) values (
    v_code,
    v_supplier_name,
    v_contact_name,
    v_contact_phone,
    v_contact_email
  )
  returning supplier_id into v_supplier_id;
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'SupplierCreated',
    'Supplier', v_supplier_id, null, 1, null,
    pg_catalog.jsonb_build_object(
      'supplier_code', v_code,
      'supplier_name', v_supplier_name,
      'supplier_status', 'ACTIVE',
      'contact_name', v_contact_name,
      'contact_phone', v_contact_phone,
      'contact_email', v_contact_email
    ),
    'Supplier created.',
    pg_catalog.jsonb_build_object('supplier_id', v_supplier_id)
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request, 'CONFLICT', 'The supplier code is already in use.', 'ADMIN', v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE', 'The supplier could not be created safely.', 'ADMIN', v_name
    );
end;
$$;
