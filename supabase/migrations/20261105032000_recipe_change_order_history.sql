-- Read-only source history; never materialize native adjustment authority.
create function atlas_legacy.import_recipe_change_order_history(
  snapshot jsonb, importing_actor uuid default null, reviewed_plan text default null
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare
  existing atlas_legacy.import_batches%rowtype;
  row_data jsonb;
  table_name text;
  expected_scope text;
  total bigint;
  checksum text;
  plan text;
  batch uuid;
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',message='LOCAL_OPERATOR_ONLY';
  end if;
  if jsonb_typeof(snapshot) is distinct from 'object'
    or snapshot->>'contract_version' is distinct from 'OPS-V1-RECIPE-HISTORY.v1'
    or snapshot->>'source_system' is distinct from 'OPS_V1_RECIPE_HISTORY'
    or snapshot->>'source_project_ref' is distinct from 'qnthofvccilhnefdcxnz'
    or nullif(btrim(snapshot->>'snapshot_id'),'') is null
    or nullif(btrim(snapshot->>'extractor_version'),'') is null
    or atlas_core.pa_05b_safe_timestamptz(snapshot->>'exported_at') is null
    or jsonb_typeof(snapshot->'records') is distinct from 'array'
    or jsonb_typeof(snapshot->'source_counts') is distinct from 'object'
    or snapshot->'source_access'->>'superuser' is distinct from 'false'
    or snapshot->'source_access'->>'bypassRls' is distinct from 'true'
    or snapshot->'source_access'->>'hasRequiredSelect' is distinct from 'true'
    or (snapshot->'source_access'->>'transactionReadOnly' is distinct from 'on' and (
      snapshot->'source_access'->>'createRole' is distinct from 'false'
      or snapshot->'source_access'->>'createDb' is distinct from 'false'
      or snapshot->'source_access'->>'hasNonSelectTablePrivilege' is distinct from 'false')) then
    raise exception using errcode='22023',message='SOURCE_SNAPSHOT_INVALID';
  end if;
  checksum := atlas_legacy.master_snapshot_hash(snapshot-'snapshot_checksum');
  if snapshot->>'snapshot_checksum' is distinct from checksum then
    raise exception using errcode='22023',message='SNAPSHOT_CHECKSUM_MISMATCH';
  end if;
  if (select count(*) from jsonb_object_keys(snapshot->'source_counts'))<>4 then
    raise exception using errcode='22023',message='SOURCE_COMPLETENESS_INVALID';
  end if;
  foreach table_name in array array['ingredient_change_orders','system_bom_change_orders','school_wide_overrides','school_recipe_overrides'] loop
    select count(*) into total from jsonb_array_elements(snapshot->'records') r where r->>'source_table'=table_name;
    if snapshot->'source_counts'->>table_name is distinct from total::text then
      raise exception using errcode='22023',message='SOURCE_COMPLETENESS_INVALID';
    end if;
  end loop;
  for row_data in select value from jsonb_array_elements(snapshot->'records') loop
    expected_scope := case row_data->>'source_table'
      when 'ingredient_change_orders' then 'SYSTEM_INGREDIENT'
      when 'system_bom_change_orders' then 'SYSTEM_DISH'
      when 'school_wide_overrides' then 'SCHOOL'
      when 'school_recipe_overrides' then 'SCHOOL_DISH' end;
    if expected_scope is null or row_data->>'scope_kind' is distinct from expected_scope
      or jsonb_typeof(row_data->'legacy_id') is distinct from 'string'
      or coalesce(row_data->>'legacy_id','') !~ '^[1-9][0-9]*$'
      or jsonb_typeof(row_data->'source_active') is distinct from 'boolean'
      or coalesce(row_data->>'action','') not in ('ADD','REPLACE','ADJUST_QUANTITY','REMOVE')
      or jsonb_typeof(row_data->'source_record') is distinct from 'object'
      or not row_data ?& array['effective_from','source_created_at','source_school_type_id','dish_name','school_name','ingredient_name','substitute_name','quantity','unit_name','note']
      or exists(select 1 from jsonb_each(row_data) field where field.key=any(array['effective_from','source_created_at','source_school_type_id','dish_name','school_name','ingredient_name','substitute_name','quantity','unit_name','note']) and jsonb_typeof(field.value) not in ('null','string'))
      or (row_data->>'effective_from' is not null and atlas_core.rmvp_02b_safe_date(row_data->>'effective_from') is null)
      or (row_data->>'quantity' is not null and row_data->>'quantity' !~ '^-?[0-9]+([.][0-9]+)?$') then
      raise exception using errcode='22023',message='SOURCE_RECORD_INVALID';
    end if;
  end loop;
  if exists(select 1 from jsonb_array_elements(snapshot->'records') r group by r->>'source_table',r->>'legacy_id' having count(*)>1) then
    raise exception using errcode='22023',message='DUPLICATE_SOURCE_IDENTITY';
  end if;
  -- Serialize source observations, including different IDs with the same export time.
  perform pg_advisory_xact_lock(hashtextextended('OPS_V1_RECIPE_HISTORY',0));
  select * into existing from atlas_legacy.import_batches b
    where b.source_system='OPS_V1_RECIPE_HISTORY' and b.snapshot_id=snapshot->>'snapshot_id';
  if existing.import_batch_id is not null and existing.snapshot_checksum<>checksum then
    raise exception using errcode='22023',message='SNAPSHOT_IDENTITY_CONFLICT';
  end if;
  plan := atlas_legacy.master_snapshot_hash(jsonb_build_object('snapshot_checksum',checksum,'mode','ARCHIVE_ONLY'));
  if reviewed_plan is null then
    return jsonb_build_object('status','PREVIEW','records',jsonb_array_length(snapshot->'records'),'plan_checksum',plan,'native_adjustment_writes',0);
  end if;
  if reviewed_plan<>plan then
    raise exception using errcode='22023',message='REVIEWED_PLAN_MISMATCH';
  end if;
  if importing_actor is null or not exists(select 1 from atlas_core.actors a where a.actor_id=importing_actor and a.actor_status='ACTIVE') then
    raise exception using errcode='22023',message='ACTIVE_IMPORT_ACTOR_REQUIRED';
  end if;
  if existing.import_batch_id is not null then
    if existing.operator_actor_id is distinct from importing_actor then
      raise exception using errcode='22023',message='REPLAY_ACTOR_MISMATCH';
    end if;
    return jsonb_build_object('status','REPLAYED','import_batch_id',existing.import_batch_id,'records',jsonb_array_length(snapshot->'records'),'native_adjustment_writes',0);
  end if;
  if exists(select 1 from atlas_legacy.import_batches b where b.source_system='OPS_V1_RECIPE_HISTORY' and b.exported_at=(snapshot->>'exported_at')::timestamptz and b.snapshot_checksum<>checksum) then
    raise exception using errcode='22023',message='AMBIGUOUS_SOURCE_OBSERVATION';
  end if;
  insert into atlas_legacy.import_batches(source_system,snapshot_id,snapshot_checksum,exported_at,import_status,source_counts,target_counts,operation_counts,result_payload,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version)
  values('OPS_V1_RECIPE_HISTORY',snapshot->>'snapshot_id',checksum,(snapshot->>'exported_at')::timestamptz,'COMPLETED',snapshot->'source_counts','{}',jsonb_build_object('inserted',jsonb_array_length(snapshot->'records'),'updated',0,'skipped',0,'rejected',0),jsonb_build_object('snapshot',snapshot),transaction_timestamp(),importing_actor,current_user,plan,'OPS-V1-RECIPE-HISTORY.v1') returning import_batch_id into batch;
  return jsonb_build_object('status','IMPORTED','import_batch_id',batch,'records',jsonb_array_length(snapshot->'records'),'native_adjustment_writes',0);
end $$;
revoke all on function atlas_legacy.import_recipe_change_order_history(jsonb,uuid,text) from public,anon,authenticated,service_role;

grant usage on schema atlas_legacy to atlas_read_runtime;
grant select on atlas_legacy.import_batches to atlas_read_runtime;
create policy recipe_history_receipt_read on atlas_legacy.import_batches for select to atlas_read_runtime
  using(source_system='OPS_V1_RECIPE_HISTORY' and import_status='COMPLETED');

create function atlas_legacy.recipe_change_order_history() returns jsonb
language sql stable security invoker set search_path='' as $$
  select coalesce(jsonb_agg(observation.record-'source_record' order by observation.record->>'effective_from' desc nulls last,observation.record->>'source_table',observation.record->>'legacy_id'),'[]'::jsonb)
  from (
    select distinct on (r->>'source_table',r->>'legacy_id') r as record
    from atlas_legacy.import_batches b
    cross join lateral jsonb_array_elements(b.result_payload->'snapshot'->'records') r
    where b.source_system='OPS_V1_RECIPE_HISTORY' and b.import_status='COMPLETED'
    order by r->>'source_table',r->>'legacy_id',b.exported_at desc,b.snapshot_id
  ) observation
$$;
revoke all on function atlas_legacy.recipe_change_order_history() from public,anon,authenticated,service_role;
grant execute on function atlas_legacy.recipe_change_order_history() to atlas_read_runtime;
alter function atlas_legacy.import_recipe_change_order_history(jsonb,uuid,text) owner to atlas_owner;
alter function atlas_legacy.recipe_change_order_history() owner to atlas_owner;
grant execute on function atlas_legacy.import_recipe_change_order_history(jsonb,uuid,text) to postgres;
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
    'workbench', v_workbench || pg_catalog.jsonb_build_object('legacy_history', atlas_legacy.recipe_change_order_history()),
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


