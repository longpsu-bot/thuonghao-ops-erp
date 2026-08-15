create or replace function atlas_api.update_school_portion_defaults_bulk(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'update_school_portion_defaults_bulk';
  v_errors jsonb := '[]'::jsonb;
  v_requested_at timestamptz;
  v_changes jsonb;
  v_change jsonb;
  v_change_index integer := 0;
  v_school_ids uuid[] := array[]::uuid[];
  v_school_id uuid;
  v_expected_version bigint;
  v_student_numeric numeric;
  v_teacher_numeric numeric;
  v_student integer;
  v_teacher integer;
  v_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_missing jsonb := '[]'::jsonb;
  v_stale jsonb := '[]'::jsonb;
  v_unchanged jsonb := '[]'::jsonb;
  v_school atlas_admin.schools%rowtype;
  v_before jsonb;
  v_after jsonb;
  v_event jsonb;
  v_updated_schools jsonb := '[]'::jsonb;
  v_new_versions jsonb := '[]'::jsonb;
  v_domain_event_ids jsonb := '[]'::jsonb;
  v_audit_event_ids jsonb := '[]'::jsonb;
  v_response jsonb;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb),
      'VALIDATION_FAILED',
      'The bulk command request must be a JSON object.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'request',
          'message', 'A JSON object is required.'
        )
      )
    );
  end if;

  if request ->> 'contract_version' is distinct from 'RMVP-01.v2' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use RMVP-01.v2.'
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
  if request ? 'expected_version' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_version',
        'message', 'Bulk School commands use one expected_version per changed School.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at');
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
        'message', 'The reason_note field is required and may be null.'
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
  elsif request -> 'payload' -> 'changes' is null
     or pg_catalog.jsonb_typeof(request -> 'payload' -> 'changes') <> 'array' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload.changes',
        'message', 'An array of changed Schools is required.'
      )
    );
  else
    v_changes := request -> 'payload' -> 'changes';
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The bulk School defaults command envelope is invalid.',
      'ADMIN',
      v_name,
      false,
      v_errors
    );
  end if;

  if pg_catalog.jsonb_array_length(v_changes) = 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'At least one changed School is required.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.changes',
          'message', 'The change list must not be empty.'
        )
      )
    );
  end if;

  for v_change in
    select change_item.value
    from pg_catalog.jsonb_array_elements(v_changes) with ordinality as change_item(value, position)
    order by change_item.position
  loop
    v_change_index := v_change_index + 1;
    v_school_id := null;
    v_expected_version := null;
    v_student_numeric := null;
    v_teacher_numeric := null;

    if pg_catalog.jsonb_typeof(v_change) = 'object' then
      v_school_id := atlas_core.pa_05b_safe_uuid(v_change ->> 'school_id');
      if pg_catalog.jsonb_typeof(v_change -> 'expected_version') = 'number' then
        v_expected_version := atlas_core.pa_05b_safe_bigint(
          v_change ->> 'expected_version'
        );
      end if;
      if pg_catalog.jsonb_typeof(v_change -> 'default_student_portions') = 'number' then
        v_student_numeric := atlas_core.pa_05b_safe_numeric(
          v_change ->> 'default_student_portions'
        );
      end if;
      if pg_catalog.jsonb_typeof(v_change -> 'default_teacher_portions') = 'number' then
        v_teacher_numeric := atlas_core.pa_05b_safe_numeric(
          v_change ->> 'default_teacher_portions'
        );
      end if;
    end if;

    if pg_catalog.jsonb_typeof(v_change) <> 'object'
       or v_school_id is null
       or v_expected_version is null
       or v_expected_version <= 0
       or v_student_numeric is null
       or v_student_numeric < 0
       or v_student_numeric > 2147483647
       or v_student_numeric <> pg_catalog.trunc(v_student_numeric)
       or v_teacher_numeric is null
       or v_teacher_numeric < 0
       or v_teacher_numeric > 2147483647
       or v_teacher_numeric <> pg_catalog.trunc(v_teacher_numeric) then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.changes[' || (v_change_index - 1)::text || ']',
          'message', 'school_id, a positive expected_version, and non-negative integer student and teacher defaults are required.'
        )
      );
    else
      v_school_ids := pg_catalog.array_append(v_school_ids, v_school_id);
    end if;
  end loop;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'One or more changed School values are invalid.',
      'ADMIN',
      v_name,
      false,
      v_errors
    );
  end if;

  if (
    select pg_catalog.count(distinct requested_school_id)
    from pg_catalog.unnest(v_school_ids) as requested_school_id
  ) <> pg_catalog.cardinality(v_school_ids) then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Each School may appear only once in a bulk Save.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.changes',
          'message', 'Duplicate school_id values are not allowed.'
        )
      )
    );
  end if;

  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.schools.write',
    v_name
  );
  if v_context ? 'error' then
    return v_context -> 'error';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_name,
    'ADMIN',
    'schools:bulk'
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return v_begin -> 'response';
  end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform school.school_id
  from atlas_admin.schools school
  where school.school_id = any(v_school_ids)
  order by school.school_id
  for update;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('school_id', requested_school_id)
      order by requested_school_id
    ),
    '[]'::jsonb
  )
  into v_missing
  from pg_catalog.unnest(v_school_ids) as requested_school_id
  left join atlas_admin.schools school
    on school.school_id = requested_school_id
  where school.school_id is null;

  if pg_catalog.jsonb_array_length(v_missing) > 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'NOT_FOUND',
        'One or more Schools were not found. No School was updated.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        v_missing
      ),
      false
    );
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', school.school_id,
        'school_code', school.school_code,
        'school_name', school.school_name,
        'expected_version', atlas_core.pa_05b_safe_bigint(change_item.value ->> 'expected_version'),
        'actual_version', school.version
      )
      order by school.school_id
    ),
    '[]'::jsonb
  )
  into v_stale
  from pg_catalog.jsonb_array_elements(v_changes) as change_item(value)
  join atlas_admin.schools school
    on school.school_id = atlas_core.pa_05b_safe_uuid(change_item.value ->> 'school_id')
  where school.version <> atlas_core.pa_05b_safe_bigint(
    change_item.value ->> 'expected_version'
  );

  if pg_catalog.jsonb_array_length(v_stale) > 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'One or more Schools changed after they were read. Refresh and review before saving.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        v_stale
      ),
      false
    );
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', school.school_id,
        'school_code', school.school_code,
        'school_name', school.school_name
      )
      order by school.school_id
    ),
    '[]'::jsonb
  )
  into v_unchanged
  from pg_catalog.jsonb_array_elements(v_changes) as change_item(value)
  join atlas_admin.schools school
    on school.school_id = atlas_core.pa_05b_safe_uuid(change_item.value ->> 'school_id')
  where school.default_student_portions = (
          atlas_core.pa_05b_safe_numeric(
            change_item.value ->> 'default_student_portions'
          )
        )::integer
    and school.default_teacher_portions = (
          atlas_core.pa_05b_safe_numeric(
            change_item.value ->> 'default_teacher_portions'
          )
        )::integer;

  if pg_catalog.jsonb_array_length(v_unchanged) > 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The bulk Save contains a School whose defaults did not change.',
        'ADMIN',
        v_name,
        false,
        pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'payload.changes',
            'message', 'Only changed Schools may be submitted.'
          )
        ),
        v_unchanged
      ),
      false
    );
  end if;

  for v_school in
    select school.*
    from atlas_admin.schools school
    where school.school_id = any(v_school_ids)
    order by school.school_id
  loop
    select change_item.value
    into v_change
    from pg_catalog.jsonb_array_elements(v_changes) as change_item(value)
    where atlas_core.pa_05b_safe_uuid(change_item.value ->> 'school_id') = v_school.school_id;

    v_student := (
      atlas_core.pa_05b_safe_numeric(
        v_change ->> 'default_student_portions'
      )
    )::integer;
    v_teacher := (
      atlas_core.pa_05b_safe_numeric(
        v_change ->> 'default_teacher_portions'
      )
    )::integer;
    v_before := pg_catalog.jsonb_build_object(
      'default_student_portions', v_school.default_student_portions,
      'default_teacher_portions', v_school.default_teacher_portions
    );

    update atlas_admin.schools school
    set default_student_portions = v_student,
        default_teacher_portions = v_teacher,
        version = school.version + 1,
        updated_at = pg_catalog.transaction_timestamp()
    where school.school_id = v_school.school_id;

    v_after := pg_catalog.jsonb_build_object(
      'default_student_portions', v_student,
      'default_teacher_portions', v_teacher
    );
    v_event := atlas_core.rmvp_01_record_change(
      request,
      v_actor_id,
      v_receipt_id,
      'SchoolPortionDefaultsUpdated',
      'School',
      v_school.school_id,
      v_school.version,
      v_school.version + 1,
      v_before,
      v_after
    );

    v_updated_schools := v_updated_schools || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'school_id', v_school.school_id,
        'version', v_school.version + 1,
        'default_student_portions', v_student,
        'default_teacher_portions', v_teacher
      )
    );
    v_new_versions := v_new_versions || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'school_id', v_school.school_id,
        'version', v_school.version + 1
      )
    );
    v_domain_event_ids := v_domain_event_ids || pg_catalog.jsonb_build_array(
      v_event -> 'domain_event_id'
    );
    v_audit_event_ids := v_audit_event_ids || pg_catalog.jsonb_build_array(
      v_event -> 'audit_event_id'
    );
  end loop;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-01.v2',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'school_ids', pg_catalog.to_jsonb(v_school_ids)
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'schools', v_new_versions
    ),
    'updated_schools', v_updated_schools,
    'emitted_event_ids', v_domain_event_ids,
    'audit_event_ids', v_audit_event_ids,
    'safe_operator_message', pg_catalog.format(
      '%s School portion defaults saved.',
      pg_catalog.cardinality(v_school_ids)
    ),
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );

  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Schools could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The School defaults could not be saved safely.',
      'ADMIN',
      v_name
    );
end;
$$;

revoke execute on function atlas_api.update_school_portion_defaults_bulk(jsonb)
  from public, anon, service_role;
grant execute on function atlas_api.update_school_portion_defaults_bulk(jsonb)
  to authenticated;

comment on function atlas_api.update_school_portion_defaults_bulk(jsonb) is
  'RMVP-01.v2 atomic multi-School command for changed non-negative student and teacher portion defaults; every School carries its own expected version.';

grant atlas_master_data_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_master_data_command_runtime;
alter function atlas_api.update_school_portion_defaults_bulk(jsonb)
  owner to atlas_master_data_command_runtime;
revoke create on schema atlas_api from atlas_master_data_command_runtime;
revoke atlas_master_data_command_runtime from postgres;
