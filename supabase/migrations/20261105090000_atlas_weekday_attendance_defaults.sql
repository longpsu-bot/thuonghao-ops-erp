-- Additive School weekday attendance defaults. Existing command/read owners and grants remain.
create or replace function atlas_core.valid_weekday_portion_defaults(value jsonb)
returns boolean language plpgsql immutable security invoker set search_path = '' as $$
declare day record; portion record; count_value numeric;
begin
  if value is null or pg_catalog.jsonb_typeof(value) <> 'object' then return false; end if;
  for day in select * from pg_catalog.jsonb_each(value) loop
    if day.key not in ('1','2','3','4','5') or pg_catalog.jsonb_typeof(day.value) <> 'object' then return false; end if;
    for portion in select * from pg_catalog.jsonb_each(day.value) loop
      if portion.key not in ('student_portions','teacher_portions') or pg_catalog.jsonb_typeof(portion.value) <> 'number' then return false; end if;
      count_value := portion.value::text::numeric;
      if count_value < 0 or count_value > 2147483647 or count_value <> pg_catalog.trunc(count_value) then return false; end if;
    end loop;
  end loop;
  return true;
end;
$$;
revoke all on function atlas_core.valid_weekday_portion_defaults(jsonb) from public, anon, authenticated, service_role;
grant execute on function atlas_core.valid_weekday_portion_defaults(jsonb) to atlas_owner, atlas_master_data_command_runtime;
alter function atlas_core.valid_weekday_portion_defaults(jsonb) owner to atlas_owner;
alter table atlas_admin.schools add column weekday_portion_defaults jsonb not null default '{}'::jsonb,
  add constraint schools_weekday_portion_defaults_check check (atlas_core.valid_weekday_portion_defaults(weekday_portion_defaults));
comment on column atlas_admin.schools.weekday_portion_defaults is 'ISO weekdays 1-5 with optional student_portions and teacher_portions; missing fields use current School defaults; zero is explicit.';
grant update (weekday_portion_defaults) on atlas_admin.schools to atlas_master_data_command_runtime;

CREATE OR REPLACE FUNCTION atlas_api.update_school_portion_defaults(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_name constant text := 'update_school_portion_defaults';
  v_payload jsonb := request -> 'payload';
  v_school_id uuid;
  v_student integer;
  v_teacher integer;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_school atlas_admin.schools%rowtype;
  v_before jsonb;
  v_after jsonb;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  v_school_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'school_id');
  begin
    v_student := (v_payload ->> 'default_student_portions')::integer;
    v_teacher := (v_payload ->> 'default_teacher_portions')::integer;
  exception when others then
    v_student := null;
    v_teacher := null;
  end;
  if v_school_id is null or v_student is null or v_teacher is null
     or v_student < 0 or v_teacher < 0
     or (v_payload ? 'weekday_portion_defaults' and not atlas_core.valid_weekday_portion_defaults(v_payload -> 'weekday_portion_defaults')) then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'School portion defaults are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload',
          'message',
          'school_id and non-negative integer student and teacher defaults are required.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request,
    v_name,
    'master_data.schools.write',
    'school:' || v_school_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select * into v_school
  from atlas_admin.schools
  where school_id = v_school_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The school was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_school.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The school changed after it was read. Refresh before saving.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_school.version
      ),
      false
    );
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'default_student_portions', v_school.default_student_portions,
    'weekday_portion_defaults', v_school.weekday_portion_defaults,
      'default_teacher_portions', v_school.default_teacher_portions
  );
  update atlas_admin.schools
  set weekday_portion_defaults = coalesce(v_payload -> 'weekday_portion_defaults', v_school.weekday_portion_defaults),
      default_student_portions = v_student,
      default_teacher_portions = v_teacher,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where school_id = v_school_id;
  v_after := pg_catalog.jsonb_build_object(
    'default_student_portions', v_student,
    'weekday_portion_defaults', coalesce(v_payload -> 'weekday_portion_defaults', v_school.weekday_portion_defaults),
      'default_teacher_portions', v_teacher
  );
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'SchoolPortionDefaultsUpdated',
    'School', v_school_id, v_school.version, v_school.version + 1,
    v_before, v_after, 'School portion defaults saved.',
    pg_catalog.jsonb_build_object('school_id', v_school_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The school could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The school defaults could not be saved safely.',
      'ADMIN',
      v_name
    );
end;
$function$

;

CREATE OR REPLACE FUNCTION atlas_api.update_school_portion_defaults_bulk(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
       or v_teacher_numeric <> pg_catalog.trunc(v_teacher_numeric)
       or (v_change ? 'weekday_portion_defaults' and not atlas_core.valid_weekday_portion_defaults(v_change -> 'weekday_portion_defaults')) then
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
        )::integer
    and (not (change_item.value ? 'weekday_portion_defaults') or school.weekday_portion_defaults = change_item.value -> 'weekday_portion_defaults');

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
      'weekday_portion_defaults', v_school.weekday_portion_defaults,
      'default_teacher_portions', v_school.default_teacher_portions
    );

    update atlas_admin.schools school
    set weekday_portion_defaults = coalesce(v_change -> 'weekday_portion_defaults', v_school.weekday_portion_defaults),
      default_student_portions = v_student,
        default_teacher_portions = v_teacher,
        version = school.version + 1,
        updated_at = pg_catalog.transaction_timestamp()
    where school.school_id = v_school.school_id;

    v_after := pg_catalog.jsonb_build_object(
      'default_student_portions', v_student,
      'weekday_portion_defaults', coalesce(v_change -> 'weekday_portion_defaults', v_school.weekday_portion_defaults),
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
        'weekday_portion_defaults', coalesce(v_change -> 'weekday_portion_defaults', v_school.weekday_portion_defaults),
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
$function$

;

CREATE OR REPLACE FUNCTION atlas_api.get_school_master_data(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_name constant text := 'get_school_master_data';
  v_error jsonb;
  v_context jsonb;
  v_items jsonb;
begin
  v_error := atlas_core.rmvp_01_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', s.school_id,
        'school_code', s.school_code,
        'school_name', s.school_name,
        'school_status', s.school_status,
        'cooking_group_id', cg.cooking_group_id,
        'cooking_group_name', cg.cooking_group_name,
        'cooking_location_id',cg.cooking_group_id,'cooking_location_name',cg.cooking_group_name,
        'cooking_location_kind',cg.location_kind,'cooking_location_host_school_id',cg.host_school_id,
        'dispatch_group_id',dg.dispatch_group_id,'dispatch_group_name',dg.dispatch_group_name,
        'version', s.version,
        'display_order', s.display_order,
        'weekday_portion_defaults', s.weekday_portion_defaults,
        'default_student_portions', s.default_student_portions,
        'default_teacher_portions', s.default_teacher_portions,
        'school_type_id', st.school_type_id,
        'school_type_name', st.school_type_name,
        'customer_id', c.customer_id,
        'customer_code', c.customer_code,
        'customer_name', c.customer_name,
        'delivery_location_id', dl.delivery_location_id,
        'delivery_location_name', dl.location_name,
        'delivery_address', dl.address_text,
        'delivery_instructions', dl.delivery_instructions,
        'contract_context', s.operational_notes
      )
      order by s.display_order, s.school_name, s.school_id
    ),
    '[]'::jsonb
  )
  into v_items
  from atlas_admin.schools s left join atlas_admin.school_cooking_group_memberships cgm on cgm.school_id=s.school_id left join atlas_admin.cooking_groups cg on cg.cooking_group_id=cgm.cooking_group_id left join atlas_admin.dispatch_group_members dgm on dgm.school_id=s.school_id left join atlas_admin.dispatch_groups dg on dg.dispatch_group_id=dgm.dispatch_group_id
  join atlas_admin.customers c on c.customer_id = s.customer_id
  join atlas_admin.delivery_locations dl
    on dl.delivery_location_id = s.default_delivery_location_id
  left join atlas_admin.school_types st on st.school_type_id = s.school_type_id;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-01.v1',
    'correlation_id', request ->> 'correlation_id',
    'schools', v_items,
    'safe_operator_message', 'Authorized school master data returned.'
  );
exception when others then
  return atlas_core.rmvp_01_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'School master data could not be returned safely.'
  );
end;
$function$

;

CREATE OR REPLACE FUNCTION atlas_core.rmvp_03a_default_attendance_rows(week_start date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  with selected_menu as (
    select menu.weekly_menu_id
    from atlas_planning.weekly_menus menu
    where menu.week_start = $1
  ),
  menu_population as (
    select distinct line.school_id, line.service_date
    from selected_menu menu
    join atlas_planning.weekly_menu_lines line
      on line.weekly_menu_id = menu.weekly_menu_id
     and line.line_status = 'ACTIVE'
    join atlas_admin.schools school
      on school.school_id = line.school_id
     and school.school_status = 'ACTIVE'
  ),
  fallback_population as (
    select
      school.school_id,
      day.service_date::date
    from atlas_admin.schools school
    cross join pg_catalog.generate_series(
      $1::timestamp,
      ($1 + 6)::timestamp,
      interval '1 day'
    ) day(service_date)
    where school.school_status = 'ACTIVE'
      and not exists (select 1 from menu_population)
  ),
  population as (
    select * from menu_population
    union all
    select * from fallback_population
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', population.school_id,
        'service_date', population.service_date,
        'student_portions', coalesce((school.weekday_portion_defaults -> (extract(isodow from population.service_date)::integer::text) ->> 'student_portions')::numeric::integer, school.default_student_portions),
        'teacher_portions', coalesce((school.weekday_portion_defaults -> (extract(isodow from population.service_date)::integer::text) ->> 'teacher_portions')::numeric::integer, school.default_teacher_portions),
        'source_row_reference',
          'default:' || school.school_code || ':' ||
          population.service_date::text
      )
      order by
        school.display_order,
        school.school_name,
        school.school_id,
        population.service_date
    ),
    '[]'::jsonb
  )
  from population
  join atlas_admin.schools school
    on school.school_id = population.school_id;
$function$

;

CREATE OR REPLACE FUNCTION atlas_core.rmvp_03a_attendance_issues(week_start date, rows jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  with canonical as (
    select value as row
    from pg_catalog.jsonb_array_elements(
      atlas_core.rmvp_03a_canonical_attendance_rows(rows)
    )
  ),
  issues as (
    select
      'BLOCKER'::text as severity,
      'EMPTY_ATTENDANCE'::text as code,
      'Attendance contains no meaningful row.'::text as message,
      null::text as source_row_reference
    where not exists (select 1 from canonical)
    union all
    select
      'BLOCKER', 'INVALID_SCHOOL_ID',
      'A row does not identify a valid school.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') is null
    union all
    select
      'BLOCKER', 'INVALID_SERVICE_DATE',
      'A row does not contain a valid ISO service date.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05d_safe_date(row ->> 'service_date') is null
    union all
    select
      'BLOCKER', 'SERVICE_DATE_OUTSIDE_WEEK',
      'An attendance row falls outside the selected service week.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05d_safe_date(row ->> 'service_date') is not null
      and atlas_core.pa_05d_safe_date(row ->> 'service_date')
        not between week_start and week_start + 6
    union all
    select
      'BLOCKER', 'INVALID_STUDENT_PORTIONS',
      'Student portions must be an explicit non-negative integer.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.rmvp_03a_safe_nonnegative_integer(
      row ->> 'student_portions'
    ) is null
    union all
    select
      'BLOCKER', 'INVALID_TEACHER_PORTIONS',
      'Teacher portions must be an explicit non-negative integer.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.rmvp_03a_safe_nonnegative_integer(
      row ->> 'teacher_portions'
    ) is null
    union all
    select
      'BLOCKER', 'UNKNOWN_SCHOOL',
      'A row references a school that does not exist.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') is not null
      and not exists (
        select 1
        from atlas_admin.schools school
        where school.school_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
      )
    union all
    select
      'BLOCKER', 'INACTIVE_SCHOOL',
      'A row references an inactive school.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
    where school.school_status <> 'ACTIVE'
    union all
    select
      'BLOCKER', 'DUPLICATE_ATTENDANCE_ASSIGNMENT',
      'The same school and date appears more than once.',
      pg_catalog.min(row ->> 'source_row_reference')
    from canonical
    group by row ->> 'school_id', row ->> 'service_date'
    having count(*) > 1
    union all
    select
      'WARNING', 'PORTIONS_DIFFER_FROM_DEFAULT',
      'Attendance differs from the current school defaults.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and school.school_status = 'ACTIVE'
    where atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'student_portions'
          ) is not null
      and atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'teacher_portions'
          ) is not null
      and (
        atlas_core.rmvp_03a_safe_nonnegative_integer(
          row ->> 'student_portions'
        ) <> coalesce((school.weekday_portion_defaults -> (extract(isodow from atlas_core.pa_05d_safe_date(row ->> 'service_date'))::integer::text) ->> 'student_portions')::numeric::integer, school.default_student_portions)
        or atlas_core.rmvp_03a_safe_nonnegative_integer(
          row ->> 'teacher_portions'
        ) <> coalesce((school.weekday_portion_defaults -> (extract(isodow from atlas_core.pa_05d_safe_date(row ->> 'service_date'))::integer::text) ->> 'teacher_portions')::numeric::integer, school.default_teacher_portions)
      )
    union all
    select
      'WARNING', 'ZERO_TOTAL_PORTIONS',
      'Student and teacher portions total zero for this school and date.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'student_portions'
          ) = 0
      and atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'teacher_portions'
          ) = 0
    union all
    select
      'WARNING', 'DIFFERS_FROM_APPROVED_ATTENDANCE',
      'These portions differ from the latest approved snapshot.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_planning.attendance_batches batch
      on batch.period_start = $1
     and batch.period_end = $1 + 6
     and batch.latest_approval_snapshot_id is not null
    left join atlas_planning.attendance_approval_snapshot_lines approved
      on approved.attendance_approval_snapshot_id =
          batch.latest_approval_snapshot_id
     and approved.school_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and approved.service_date =
          atlas_core.pa_05d_safe_date(row ->> 'service_date')
    where approved.attendance_line_id is null
       or approved.student_portions is distinct from
          atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'student_portions'
          )
       or approved.teacher_portions is distinct from
          atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'teacher_portions'
          )
    union all
    select
      'WARNING', 'OMITS_APPROVED_ATTENDANCE',
      'The draft omits a row from the latest approved snapshot.',
      approved.source_row_reference
    from atlas_planning.attendance_batches batch
    join atlas_planning.attendance_approval_snapshot_lines approved
      on approved.attendance_approval_snapshot_id =
          batch.latest_approval_snapshot_id
    where batch.period_start = $1
      and batch.period_end = $1 + 6
      and not exists (
        select 1
        from canonical
        where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') =
              approved.school_id
          and atlas_core.pa_05d_safe_date(row ->> 'service_date') =
              approved.service_date
      )
  )
  select pg_catalog.jsonb_build_object(
    'blockers',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'code', code,
            'message', message,
            'source_row_reference', source_row_reference
          )
          order by code, source_row_reference nulls first
        )
        from issues
        where severity = 'BLOCKER'
      ),
      '[]'::jsonb
    ),
    'warnings',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'code', code,
            'message', message,
            'source_row_reference', source_row_reference
          )
          order by code, source_row_reference nulls first
        )
        from issues
        where severity = 'WARNING'
      ),
      '[]'::jsonb
    )
  );
$function$

;

CREATE OR REPLACE FUNCTION atlas_core.rmvp_03a_planning_workbench_payload(target_week_start date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_menu atlas_planning.weekly_menus%rowtype;
  v_attendance atlas_planning.attendance_batches%rowtype;
  v_menu_rows jsonb := '[]'::jsonb;
  v_attendance_rows jsonb := '[]'::jsonb;
  v_menu_issues jsonb;
  v_attendance_issues jsonb;
  v_coverage_warnings jsonb := '[]'::jsonb;
  v_missing_attendance integer := 0;
  v_without_menu integer := 0;
begin
  select *
    into v_menu
  from atlas_planning.weekly_menus menu
  where menu.week_start = target_week_start;

  if found then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'weekly_menu_line_id', line.weekly_menu_line_id,
          'school_id', line.school_id,
          'service_date', line.service_date,
          'menu_slot_code', line.menu_slot_code,
          'dish_id', line.dish_id,
          'line_status', line.line_status,
          'source_row_reference', line.source_row_reference,
          'updated_by_actor_id', line.updated_by_actor_id,
          'updated_at', line.updated_at
        )
        order by
          school.display_order,
          school.school_name,
          school.school_id,
          line.service_date,
          line.menu_slot_code,
          line.weekly_menu_line_id
      ),
      '[]'::jsonb
    )
      into v_menu_rows
    from atlas_planning.weekly_menu_lines line
    join atlas_admin.schools school on school.school_id = line.school_id
    where line.weekly_menu_id = v_menu.weekly_menu_id;
  end if;

  select *
    into v_attendance
  from atlas_planning.attendance_batches batch
  where batch.period_start = target_week_start
    and batch.period_end = target_week_start + 6;

  if found then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'attendance_line_id', line.attendance_line_id,
          'school_id', line.school_id,
          'service_date', line.service_date,
          'student_portions', line.student_portions,
          'teacher_portions', line.teacher_portions,
          'line_status', line.line_status,
          'source_row_reference', line.source_row_reference,
          'updated_by_actor_id', line.updated_by_actor_id,
          'updated_at', line.updated_at
        )
        order by
          school.display_order,
          school.school_name,
          school.school_id,
          line.service_date,
          line.attendance_line_id
      ),
      '[]'::jsonb
    )
      into v_attendance_rows
    from atlas_planning.attendance_lines line
    join atlas_admin.schools school on school.school_id = line.school_id
    where line.attendance_batch_id = v_attendance.attendance_batch_id;
  end if;

  v_menu_issues := atlas_core.rmvp_03a_menu_issues(
    target_week_start,
    (
      select coalesce(pg_catalog.jsonb_agg(row), '[]'::jsonb)
      from pg_catalog.jsonb_array_elements(v_menu_rows) row
      where row ->> 'line_status' = 'ACTIVE'
    )
  );
  v_attendance_issues := atlas_core.rmvp_03a_attendance_issues(
    target_week_start,
    (
      select coalesce(pg_catalog.jsonb_agg(row), '[]'::jsonb)
      from pg_catalog.jsonb_array_elements(v_attendance_rows) row
      where row ->> 'line_status' = 'ACTIVE'
    )
  );

  if v_menu.weekly_menu_id is not null
     and v_attendance.attendance_batch_id is not null then
    select count(*)::integer
      into v_missing_attendance
    from (
      select distinct line.school_id, line.service_date
      from atlas_planning.weekly_menu_lines line
      where line.weekly_menu_id = v_menu.weekly_menu_id
        and line.line_status = 'ACTIVE'
    ) menu_assignment
    where not exists (
      select 1
      from atlas_planning.attendance_lines attendance_line
      where attendance_line.attendance_batch_id =
          v_attendance.attendance_batch_id
        and attendance_line.line_status = 'ACTIVE'
        and attendance_line.school_id = menu_assignment.school_id
        and attendance_line.service_date = menu_assignment.service_date
    );

    select count(*)::integer
      into v_without_menu
    from atlas_planning.attendance_lines attendance_line
    where attendance_line.attendance_batch_id =
        v_attendance.attendance_batch_id
      and attendance_line.line_status = 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.weekly_menu_lines menu_line
        where menu_line.weekly_menu_id = v_menu.weekly_menu_id
          and menu_line.line_status = 'ACTIVE'
          and menu_line.school_id = attendance_line.school_id
          and menu_line.service_date = attendance_line.service_date
      );
  end if;

  if v_missing_attendance > 0 then
    v_coverage_warnings := v_coverage_warnings ||
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'MENU_ASSIGNMENT_WITHOUT_ATTENDANCE',
          'message',
            v_missing_attendance::text ||
            ' school/date menu assignments have no active attendance row.',
          'count', v_missing_attendance
        )
      );
  end if;
  if v_without_menu > 0 then
    v_coverage_warnings := v_coverage_warnings ||
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'ATTENDANCE_WITHOUT_MENU_ASSIGNMENT',
          'message',
            v_without_menu::text ||
            ' active attendance rows have no menu assignment.',
          'count', v_without_menu
        )
      );
  end if;

  return pg_catalog.jsonb_build_object(
    'week_start', target_week_start,
    'week_end', target_week_start + 6,
    'dish_types',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_type_id', dish_type.dish_type_id,
            'dish_type_code', dish_type.dish_type_code,
            'dish_type_name', dish_type.dish_type_name,
            'source_header_aliases', dish_type.source_header_aliases,
            'display_order', dish_type.display_order,
            'dish_type_status', dish_type.dish_type_status,
            'version', dish_type.version
          )
          order by
            dish_type.display_order,
            dish_type.dish_type_code,
            dish_type.dish_type_id
        )
        from atlas_admin.dish_types dish_type
        where dish_type.dish_type_status = 'ACTIVE'
      ),
      '[]'::jsonb
    ),
    'schools',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'school_id', school.school_id,
            'school_code', school.school_code,
            'school_name', school.school_name,
            'school_status', school.school_status,
            'display_order', school.display_order,
            'school_type_id', school.school_type_id,
            'weekday_portion_defaults', school.weekday_portion_defaults,
            'default_student_portions',
              school.default_student_portions,
            'default_teacher_portions',
              school.default_teacher_portions
          )
          order by
            school.display_order,
            school.school_name,
            school.school_id
        )
        from atlas_admin.schools school
      ),
      '[]'::jsonb
    ),
    'dishes',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_id', dish.dish_id,
            'dish_code', dish.dish_code,
            'dish_name', dish.dish_name,
            'dish_category', dish.dish_category,
            'dish_type_id', dish.dish_type_id,
            'dish_type_code', dish_type.dish_type_code,
            'dish_type_name', dish_type.dish_type_name,
            'dish_status', dish.dish_status,
            'display_order', dish.display_order,
            'requires_need_generation', dish.requires_need_generation
          )
          order by
            dish.display_order,
            dish.dish_code,
            dish.dish_id
        )
        from atlas_admin.dishes dish
        left join atlas_admin.dish_types dish_type
          on dish_type.dish_type_id = dish.dish_type_id
      ),
      '[]'::jsonb
    ),
    'google_sheet_sources',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'weekly_menu_google_source_id',
              source.weekly_menu_google_source_id,
            'source_code', source.source_code,
            'source_name', source.source_name,
            'source_status', source.source_status,
            'display_order', source.display_order
          )
          order by
            source.display_order,
            source.source_code,
            source.weekly_menu_google_source_id
        )
        from atlas_planning.weekly_menu_google_sources source
        where source.source_status = 'ACTIVE'
      ),
      '[]'::jsonb
    ),
    'weekly_menu',
    case
      when v_menu.weekly_menu_id is null then null
      else pg_catalog.jsonb_build_object(
        'weekly_menu_id', v_menu.weekly_menu_id,
        'week_start', v_menu.week_start,
        'week_end', v_menu.week_end,
        'source_type', v_menu.source_type,
        'source_name', v_menu.source_name,
        'source_signature', v_menu.source_signature,
        'weekly_menu_status', v_menu.weekly_menu_status,
        'row_count', v_menu.row_count,
        'imported_by_actor_id', v_menu.imported_by_actor_id,
        'imported_at', v_menu.imported_at,
        'latest_approved_by_actor_id',
          v_menu.latest_approved_by_actor_id,
        'latest_approved_at', v_menu.latest_approved_at,
        'latest_approval_snapshot_id',
          v_menu.latest_approval_snapshot_id,
        'version', v_menu.version,
        'created_at', v_menu.created_at,
        'updated_at', v_menu.updated_at,
        'lines', v_menu_rows,
        'issues', v_menu_issues,
        'change_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'audit_event_id', audit.audit_event_id,
                  'event_type', audit.event_type,
                  'version_before', audit.aggregate_version_before,
                  'version_after', audit.aggregate_version_after,
                  'actor_id', audit.actor_id,
                  'actor_display_name', actor.display_name,
                  'reason_code', audit.reason_code,
                  'reason_note', audit.reason_note,
                  'occurred_at', audit.occurred_at
                )
                order by audit.occurred_at desc, audit.audit_event_id
              )
              from atlas_audit.audit_events audit
              join atlas_core.actors actor
                on actor.actor_id = audit.actor_id
              where audit.aggregate_type = 'WeeklyMenu'
                and audit.aggregate_id = v_menu.weekly_menu_id
            ),
            '[]'::jsonb
          ),
        'approval_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'approval_snapshot_id',
                    snapshot.weekly_menu_approval_snapshot_id,
                  'version', snapshot.weekly_menu_version,
                  'approved_by_actor_id', snapshot.approved_by_actor_id,
                  'approved_by_display_name', actor.display_name,
                  'approved_at', snapshot.approved_at,
                  'line_count',
                    (
                      select count(*)
                      from
                        atlas_planning.weekly_menu_approval_snapshot_lines
                          snapshot_line
                      where snapshot_line.weekly_menu_approval_snapshot_id =
                        snapshot.weekly_menu_approval_snapshot_id
                    )
                )
                order by snapshot.weekly_menu_version desc
              )
              from atlas_planning.weekly_menu_approval_snapshots snapshot
              join atlas_core.actors actor
                on actor.actor_id = snapshot.approved_by_actor_id
              where snapshot.weekly_menu_id = v_menu.weekly_menu_id
            ),
            '[]'::jsonb
          )
      )
    end,
    'attendance',
    case
      when v_attendance.attendance_batch_id is null then null
      else pg_catalog.jsonb_build_object(
        'attendance_batch_id', v_attendance.attendance_batch_id,
        'period_start', v_attendance.period_start,
        'period_end', v_attendance.period_end,
        'source_type', v_attendance.source_type,
        'source_name', v_attendance.source_name,
        'source_signature', v_attendance.source_signature,
        'attendance_status', v_attendance.attendance_status,
        'row_count', v_attendance.row_count,
        'imported_by_actor_id', v_attendance.imported_by_actor_id,
        'imported_at', v_attendance.imported_at,
        'latest_approved_by_actor_id',
          v_attendance.latest_approved_by_actor_id,
        'latest_approved_at', v_attendance.latest_approved_at,
        'latest_approval_snapshot_id',
          v_attendance.latest_approval_snapshot_id,
        'version', v_attendance.version,
        'created_at', v_attendance.created_at,
        'updated_at', v_attendance.updated_at,
        'lines', v_attendance_rows,
        'issues', v_attendance_issues,
        'change_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'audit_event_id', audit.audit_event_id,
                  'event_type', audit.event_type,
                  'version_before', audit.aggregate_version_before,
                  'version_after', audit.aggregate_version_after,
                  'actor_id', audit.actor_id,
                  'actor_display_name', actor.display_name,
                  'reason_code', audit.reason_code,
                  'reason_note', audit.reason_note,
                  'occurred_at', audit.occurred_at
                )
                order by audit.occurred_at desc, audit.audit_event_id
              )
              from atlas_audit.audit_events audit
              join atlas_core.actors actor
                on actor.actor_id = audit.actor_id
              where audit.aggregate_type = 'AttendanceBatch'
                and audit.aggregate_id = v_attendance.attendance_batch_id
            ),
            '[]'::jsonb
          ),
        'approval_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'approval_snapshot_id',
                    snapshot.attendance_approval_snapshot_id,
                  'version', snapshot.attendance_version,
                  'approved_by_actor_id', snapshot.approved_by_actor_id,
                  'approved_by_display_name', actor.display_name,
                  'approved_at', snapshot.approved_at,
                  'line_count',
                    (
                      select count(*)
                      from
                        atlas_planning.attendance_approval_snapshot_lines
                          snapshot_line
                      where snapshot_line.attendance_approval_snapshot_id =
                        snapshot.attendance_approval_snapshot_id
                    )
                )
                order by snapshot.attendance_version desc
              )
              from atlas_planning.attendance_approval_snapshots snapshot
              join atlas_core.actors actor
                on actor.actor_id = snapshot.approved_by_actor_id
              where snapshot.attendance_batch_id =
                v_attendance.attendance_batch_id
            ),
            '[]'::jsonb
          )
      )
    end,
    'readiness', pg_catalog.jsonb_build_object(
      'weekly_menu_approved',
        coalesce(v_menu.weekly_menu_status = 'APPROVED', false),
      'attendance_approved',
        coalesce(v_attendance.attendance_status = 'APPROVED', false),
      'weekly_menu_approval_snapshot_id',
        v_menu.latest_approval_snapshot_id,
      'attendance_approval_snapshot_id',
        v_attendance.latest_approval_snapshot_id,
      'ready',
        coalesce(v_menu.weekly_menu_status = 'APPROVED', false)
        and coalesce(v_attendance.attendance_status = 'APPROVED', false),
      'warnings', v_coverage_warnings
    ),
    'default_attendance_preview',
      atlas_core.rmvp_03a_default_attendance_rows(target_week_start)
  );
end;
$function$

;
