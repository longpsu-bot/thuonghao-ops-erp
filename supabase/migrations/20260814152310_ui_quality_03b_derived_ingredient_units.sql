-- UI-QUALITY-03B final polish: expose each Ingredient's configured purchase
-- unit to the v2 operator workbench without changing the RMVP-02B.v1 read.

grant atlas_read_runtime to postgres with set true;
grant create on schema atlas_api to atlas_read_runtime;
set role atlas_read_runtime;

create or replace function atlas_api.get_recipe_adjustment_operator_workbench(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_recipe_adjustment_operator_workbench';
  v_validation_request jsonb;
  v_error jsonb;
  v_context jsonb;
  v_reference_date date;
  v_workbench jsonb;
  v_ingredients jsonb;
begin
  if request is null
     or pg_catalog.jsonb_typeof(request) <> 'object'
     or request ->> 'contract_version' is distinct from 'RMVP-02B.v2' then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RMVP-02B.v2',
      'error_code', 'VALIDATION_FAILED',
      'safe_message', 'The operator read requires RMVP-02B.v2.',
      'domain', 'ADMIN',
      'read_name', v_name,
      'field_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'contract_version',
          'message', 'Use RMVP-02B.v2.'
        )
      ),
      'blocking_references', '[]'::jsonb,
      'correlation_id', request ->> 'correlation_id'
    );
  end if;

  v_validation_request := request || pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02B.v1'
  );
  v_error := atlas_core.rmvp_02b_validate_read_request(
    v_validation_request,
    v_name
  );
  if v_error is not null then
    return pg_catalog.jsonb_set(
      v_error,
      '{contract_version}',
      '"RMVP-02B.v2"'::jsonb
    );
  end if;

  v_reference_date := atlas_core.rmvp_02b_safe_date(
    request -> 'payload' ->> 'as_of_date'
  );
  if v_reference_date is null then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RMVP-02B.v2',
      'error_code', 'VALIDATION_FAILED',
      'safe_message', 'An explicit valid reference date is required.',
      'domain', 'ADMIN',
      'read_name', v_name,
      'field_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.as_of_date',
          'message', 'A valid ISO date is required.'
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
      '"RMVP-02B.v2"'::jsonb
    );
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'ingredient_id', ingredient.ingredient_id,
        'ingredient_code', ingredient.ingredient_code,
        'ingredient_name', ingredient.ingredient_name,
        'ingredient_status', ingredient.ingredient_status,
        'purchase_unit_id', ingredient.purchase_unit_id,
        'purchase_unit_name', purchase_unit.unit_name
      ) order by ingredient.ingredient_name, ingredient.ingredient_id
    ),
    '[]'::jsonb
  )
  into v_ingredients
  from atlas_admin.ingredients as ingredient
  left join atlas_admin.units as purchase_unit
    on purchase_unit.unit_id = ingredient.purchase_unit_id;

  v_workbench := pg_catalog.jsonb_set(
    atlas_core.uiq03b_recipe_adjustment_operator_payload(v_reference_date),
    '{ingredients}',
    v_ingredients
  );

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02B.v2',
    'correlation_id', request ->> 'correlation_id',
    'workbench', v_workbench,
    'safe_operator_message',
      'Authorized Recipe adjustment operator workbench returned.'
  );
exception when others then
  return pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RMVP-02B.v2',
    'error_code', 'INTERNAL_READ_FAILURE',
    'safe_message',
      'Recipe adjustment operator data could not be returned safely.',
    'domain', 'ADMIN',
    'read_name', v_name,
    'field_errors', '[]'::jsonb,
    'blocking_references', '[]'::jsonb,
    'correlation_id', request ->> 'correlation_id'
  );
end;
$$;

reset role;
revoke create on schema atlas_api from atlas_read_runtime;

comment on function atlas_api.get_recipe_adjustment_operator_workbench(jsonb)
is 'RMVP-02B.v2 explicit-date operator read with Ingredient purchase-unit context, server-derived temporal state, human-reference catalogs, issuance provenance, immutable business history, and internal command identity.';

revoke atlas_read_runtime from postgres;
