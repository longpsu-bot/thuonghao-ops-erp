-- PLANNING-CONTRACT-01
-- D-036 additive Planning completion and atomic generation boundaries.
-- Existing v1 APIs remain callable; this migration adds the v2 path and a
-- transaction-local internal-call seam so composite commands own one receipt.

reset role;
grant atlas_planning_command_runtime, atlas_need_generation_runtime,
  atlas_planning_materialization_runtime, atlas_read_runtime
to postgres with set true;
set role atlas_owner;

create or replace function atlas_core.planning_contract_01_command_error(
  request jsonb,
  command_name text,
  contract_version text,
  error_code text,
  safe_message text,
  field_errors jsonb default '[]'::jsonb,
  blockers jsonb default '[]'::jsonb,
  actual_version bigint default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select atlas_core.pa_05b_command_error(
    request,
    error_code,
    safe_message,
    'PLANNING',
    command_name,
    false,
    coalesce(field_errors, '[]'::jsonb),
    coalesce(blockers, '[]'::jsonb),
    actual_version
  ) || pg_catalog.jsonb_build_object('contract_version', contract_version);
$$;

create or replace function atlas_core.planning_contract_01_validate_command(
  request jsonb,
  command_name text,
  contract_version text
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
  v_requested_at timestamptz;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.planning_contract_01_command_error(
      coalesce(request, '{}'::jsonb), command_name, contract_version,
      'VALIDATION_FAILED', 'The command request must be a JSON object.'
    );
  end if;
  if request - array[
    'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
    'expected_version', 'requested_by_auth_subject', 'requested_at',
    'reason_code', 'reason_note', 'payload'
  ] <> '{}'::jsonb or not (request ?& array[
    'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
    'expected_version', 'requested_by_auth_subject', 'requested_at',
    'reason_code', 'reason_note', 'payload'
  ]) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'request',
        'message', 'The complete exact Atlas command envelope is required.'
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from contract_version then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use ' || contract_version || '.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
     or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
     or atlas_core.pa_05b_safe_uuid(
       request ->> 'requested_by_auth_subject'
     ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'identity',
        'message', 'Valid command, correlation, and subject UUIDs are required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
     or pg_catalog.length(request ->> 'idempotency_key') > 200 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'idempotency_key',
        'message', 'A nonblank key of at most 200 characters is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') < 1 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_version',
        'message', 'A positive expected version is required.'
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
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = ''
     or not (request ? 'reason_note')
     or (request -> 'reason_note' <> 'null'::jsonb
       and pg_catalog.jsonb_typeof(request -> 'reason_note') <> 'string') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason',
        'message', 'A reason code and null-or-text reason note are required.'
      )
    );
  end if;
  if pg_catalog.jsonb_typeof(request -> 'payload') is distinct from 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload', 'message', 'A JSON object is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.planning_contract_01_command_error(
      request, command_name, contract_version, 'VALIDATION_FAILED',
      'The Planning v2 command envelope is invalid.', v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_core.planning_contract_01_internal_context(
  request jsonb
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_receipt_id uuid := atlas_core.pa_05b_safe_uuid(
    pg_catalog.current_setting(
      'atlas.planning_contract_01_receipt_id', true
    )
  );
  v_actor_id uuid := atlas_core.pa_05b_safe_uuid(
    pg_catalog.current_setting(
      'atlas.planning_contract_01_actor_id', true
    )
  );
  v_command_name text := pg_catalog.current_setting(
    'atlas.planning_contract_01_command_name', true
  );
begin
  if v_receipt_id is null or v_actor_id is null
     or v_command_name not in (
       'save_weekly_menu', 'save_attendance', 'save_pantry',
       'execute_need_generation'
     ) then
    return null;
  end if;
  if not exists (
    select 1
    from atlas_core.command_receipts receipt
    where receipt.command_receipt_id = v_receipt_id
      and receipt.command_id = atlas_core.pa_05b_safe_uuid(
        request ->> 'command_id'
      )
      and receipt.actor_id = v_actor_id
      and receipt.command_name = v_command_name
      and receipt.outcome in ('IN_PROGRESS', 'COMPLETED')
  ) then
    return null;
  end if;
  return pg_catalog.jsonb_build_object(
    'actor_id', v_actor_id,
    'receipt_id', v_receipt_id,
    'command_name', v_command_name
  );
end;
$$;

create or replace function atlas_core.planning_contract_01_legacy_request(
  request jsonb,
  contract_version text,
  expected_version bigint,
  reason_code text,
  reason_note text,
  payload jsonb
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', contract_version,
    'command_id', request -> 'command_id',
    'correlation_id', request -> 'correlation_id',
    'idempotency_key', request -> 'idempotency_key',
    'expected_version', expected_version,
    'requested_by_auth_subject', request -> 'requested_by_auth_subject',
    'requested_at', request -> 'requested_at',
    'reason_code', reason_code,
    'reason_note', pg_catalog.to_jsonb(reason_note),
    'payload', payload
  );
$$;

create or replace function atlas_core.planning_contract_01_finish_receipt(
  p_receipt_id uuid,
  p_response jsonb,
  p_succeeded boolean
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
begin
  update atlas_core.command_receipts receipt
  set outcome = case
        when p_succeeded then 'COMPLETED' else 'FAILED_NON_RETRYABLE'
      end,
      response_payload = p_response,
      error_code = case
        when p_succeeded then null else p_response ->> 'error_code'
      end,
      completed_at = pg_catalog.transaction_timestamp()
  where receipt.command_receipt_id = p_receipt_id
    and receipt.command_name in (
      'save_weekly_menu', 'save_attendance', 'save_pantry',
      'execute_need_generation'
    );
  return p_response;
end;
$$;

revoke execute on function
  atlas_core.planning_contract_01_command_error(
    jsonb, text, text, text, text, jsonb, jsonb, bigint
  ),
  atlas_core.planning_contract_01_validate_command(jsonb, text, text),
  atlas_core.planning_contract_01_internal_context(jsonb),
  atlas_core.planning_contract_01_legacy_request(
    jsonb, text, bigint, text, text, jsonb
  ),
  atlas_core.planning_contract_01_finish_receipt(uuid, jsonb, boolean)
from public, anon, authenticated, service_role;

grant execute on function
  atlas_core.planning_contract_01_command_error(
    jsonb, text, text, text, text, jsonb, jsonb, bigint
  ),
  atlas_core.planning_contract_01_validate_command(jsonb, text, text),
  atlas_core.planning_contract_01_internal_context(jsonb),
  atlas_core.planning_contract_01_legacy_request(
    jsonb, text, bigint, text, text, jsonb
  ),
  atlas_core.planning_contract_01_finish_receipt(uuid, jsonb, boolean)
to atlas_planning_command_runtime, atlas_need_generation_runtime,
  atlas_planning_materialization_runtime, atlas_read_runtime;

-- Existing v1 preparers keep their public behavior. They only reuse a receipt
-- when called inside one of the four reviewed v2 security-definer commands.
grant create on schema atlas_core
to atlas_planning_command_runtime, atlas_need_generation_runtime;
set role atlas_owner;

create or replace function atlas_core.rmvp_03a_prepare_command(
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
  v_internal jsonb;
  v_actor_id uuid;
  v_begin jsonb;
begin
  v_error := atlas_core.rmvp_03a_validate_command_request(
    request, command_name
  );
  if v_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_error
    );
  end if;
  v_internal := atlas_core.planning_contract_01_internal_context(request);
  if v_internal is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'READY',
      'actor_id', v_internal ->> 'actor_id',
      'receipt_id', v_internal ->> 'receipt_id'
    );
  end if;
  v_context := atlas_core.rmvp_03a_authorize_global(
    request, capability_code, command_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_context -> 'error'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, command_name, 'PLANNING', aggregate_scope
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_begin -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY', 'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

create or replace function atlas_core.pantry_02_prepare_command(
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
  validation_error jsonb;
  actor_context jsonb;
  v_internal jsonb;
  actor_id uuid;
  begin_result jsonb;
begin
  validation_error := atlas_core.pantry_02_validate_command_request(
    request, command_name
  );
  if validation_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', validation_error
    );
  end if;
  v_internal := atlas_core.planning_contract_01_internal_context(request);
  if v_internal is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'READY',
      'actor_id', v_internal ->> 'actor_id',
      'receipt_id', v_internal ->> 'receipt_id'
    );
  end if;
  actor_context := atlas_core.pantry_02_authorize_global(
    request, capability_code, command_name
  );
  if actor_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', actor_context -> 'error'
    );
  end if;
  actor_id := atlas_core.pa_05b_safe_uuid(actor_context ->> 'actor_id');
  begin_result := atlas_core.pa_05b_begin_command(
    request, actor_id, command_name, 'PLANNING', aggregate_scope
  );
  if begin_result ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', begin_result -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY', 'actor_id', actor_id,
    'receipt_id', begin_result ->> 'receipt_id'
  );
end;
$$;

create or replace function atlas_core.rmvp_03b_prepare_command(
  request jsonb,
  command_name text,
  scope_key text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_context jsonb;
  v_internal jsonb;
  v_actor_id uuid;
  v_begin jsonb;
begin
  v_internal := atlas_core.planning_contract_01_internal_context(request);
  if v_internal is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'READY',
      'actor_id', v_internal ->> 'actor_id',
      'receipt_id', v_internal ->> 'receipt_id'
    );
  end if;
  v_context := atlas_core.rmvp_03b_authorize_global(
    request, 'planning.input_readiness.write', command_name, false
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_context -> 'error'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.rmvp_03b_begin_receipt(
    request, v_actor_id, command_name, scope_key
  );
  if v_begin ->> 'status' <> 'READY' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_begin -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY', 'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

reset role;
set role atlas_need_generation_runtime;

create or replace function atlas_core.rmvp_04_prepare_command(
  request jsonb,
  command_name text,
  aggregate_scope text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_context jsonb;
  v_internal jsonb;
  v_actor_id uuid;
  v_begin jsonb;
begin
  v_internal := atlas_core.planning_contract_01_internal_context(request);
  if v_internal is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'READY',
      'actor_id', v_internal ->> 'actor_id',
      'receipt_id', v_internal ->> 'receipt_id'
    );
  end if;
  v_context := atlas_core.rmvp_04_authorize_global(
    request, 'planning.need_generation.write', command_name, false
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_context -> 'error'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, command_name, 'PLANNING', aggregate_scope
  );
  if v_begin ->> 'status' <> 'NEW' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_begin -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY', 'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

reset role;
set role atlas_need_generation_runtime;

create or replace function atlas_core.planning_contract_01_current_need_payload(
  period_start date,
  period_end date
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', batch.confirmed_need_batch_id,
    'confirmed_need_batch_status', batch.batch_status,
    'confirmed_need_batch_version', batch.version,
    'need_generation_run_id', run.need_generation_run_id,
    'need_generation_run_version', run.version,
    'need_generation_run_status', run.run_status,
    'need_generation_release_snapshot_id',
      batch.current_need_generation_release_snapshot_id,
    'weekly_menu_id', snapshot.weekly_menu_id,
    'weekly_menu_version', snapshot.weekly_menu_version,
    'weekly_menu_approval_snapshot_id',
      snapshot.weekly_menu_approval_snapshot_id,
    'attendance_batch_id', snapshot.attendance_batch_id,
    'attendance_version', snapshot.attendance_version,
    'attendance_approval_snapshot_id',
      snapshot.attendance_approval_snapshot_id,
    'pantry_need_batch_id', snapshot.pantry_need_batch_id,
    'pantry_need_batch_version', snapshot.pantry_need_batch_version,
    'pantry_need_approval_snapshot_id',
      snapshot.pantry_need_approval_snapshot_id
  )
  from atlas_planning.confirmed_need_batches batch
  join atlas_planning.need_generation_runs run
    on run.need_generation_run_id = batch.current_need_generation_run_id
  join atlas_planning.need_generation_input_snapshots snapshot
    on snapshot.need_generation_run_id = run.need_generation_run_id
  where batch.source_kind = 'NEED_GENERATION'
    and batch.period_start = planning_contract_01_current_need_payload.period_start
    and batch.period_end = planning_contract_01_current_need_payload.period_end
  order by batch.updated_at desc, batch.confirmed_need_batch_id
  limit 1;
$$;

revoke execute on function
  atlas_core.planning_contract_01_current_need_payload(date, date)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.planning_contract_01_current_need_payload(date, date)
to atlas_read_runtime, atlas_planning_command_runtime,
  atlas_need_generation_runtime;

reset role;
set role atlas_owner;

-- The existing read runtime already owns the public Planning read boundary;
-- v2 additionally invokes the established deterministic issue calculator.
grant execute on function atlas_core.rmvp_03b_calculate_issues(
  date, date, jsonb, jsonb, jsonb
) to atlas_read_runtime;

create or replace function atlas_core.planning_contract_01_preflight_payload(
  period_start date,
  period_end date,
  supplied_candidates jsonb default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_supplied jsonb := coalesce(supplied_candidates, '{}'::jsonb);
  v_weekly jsonb;
  v_attendance jsonb;
  v_pantry jsonb;
  v_issues jsonb;
  v_extra jsonb := '[]'::jsonb;
  v_blockers integer;
  v_current jsonb;
  v_currentness text;
begin
  v_weekly := atlas_core.rmvp_03b_source_evidence(
    'WEEKLY_MENU', period_start, period_end,
    nullif(v_supplied -> 'weekly_menu', 'null'::jsonb)
  );
  v_attendance := atlas_core.rmvp_03b_source_evidence(
    'ATTENDANCE', period_start, period_end,
    nullif(v_supplied -> 'attendance', 'null'::jsonb)
  );
  v_pantry := atlas_core.rmvp_03b_source_evidence(
    'PANTRY', period_start, period_end,
    nullif(v_supplied -> 'pantry', 'null'::jsonb)
  );

  if v_weekly ->> 'selection_state' in ('AMBIGUOUS', 'STALE') then
    v_extra := v_extra || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'severity', 'BLOCKING',
        'issue_code', case v_weekly ->> 'selection_state'
          when 'AMBIGUOUS' then 'AMBIGUOUS_WEEKLY_MENU_SOURCE'
          else 'STALE_WEEKLY_MENU_SOURCE' end,
        'message', 'Weekly Menu source evidence is not uniquely current.',
        'input_type', 'WEEKLY_MENU', 'school_id', null,
        'service_date', null
      )
    );
  end if;
  if v_attendance ->> 'selection_state' in ('AMBIGUOUS', 'STALE') then
    v_extra := v_extra || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'severity', 'BLOCKING',
        'issue_code', case v_attendance ->> 'selection_state'
          when 'AMBIGUOUS' then 'AMBIGUOUS_ATTENDANCE_SOURCE'
          else 'STALE_ATTENDANCE_SOURCE' end,
        'message', 'Attendance source evidence is not uniquely current.',
        'input_type', 'ATTENDANCE', 'school_id', null,
        'service_date', null
      )
    );
  end if;
  if v_pantry ->> 'selection_state' in ('AMBIGUOUS', 'STALE') then
    v_extra := v_extra || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'severity', 'BLOCKING',
        'issue_code', case v_pantry ->> 'selection_state'
          when 'AMBIGUOUS' then 'AMBIGUOUS_PANTRY_SOURCE'
          else 'STALE_PANTRY_SOURCE' end,
        'message', 'Pantry source evidence is not uniquely current.',
        'input_type', 'PANTRY', 'school_id', null,
        'service_date', null
      )
    );
  end if;
  v_issues := atlas_core.rmvp_03b_calculate_issues(
    period_start, period_end, v_weekly, v_attendance, v_pantry
  ) || v_extra;
  select count(*)::integer into v_blockers
  from pg_catalog.jsonb_array_elements(v_issues) issue
  where issue ->> 'severity' = 'BLOCKING';

  v_current := atlas_core.planning_contract_01_current_need_payload(
    period_start, period_end
  );

  v_currentness := case
    when v_current is null then 'NOT_GENERATED'
    when v_weekly ->> 'selection_state' = 'SELECTED'
      and v_attendance ->> 'selection_state' = 'SELECTED'
      and v_pantry ->> 'selection_state' = 'SELECTED'
      and v_current ->> 'weekly_menu_id' =
        v_weekly -> 'selected' ->> 'weekly_menu_id'
      and v_current ->> 'weekly_menu_version' =
        v_weekly -> 'selected' ->> 'weekly_menu_version'
      and v_current ->> 'weekly_menu_approval_snapshot_id' =
        v_weekly -> 'selected' ->> 'weekly_menu_approval_snapshot_id'
      and v_current ->> 'attendance_batch_id' =
        v_attendance -> 'selected' ->> 'attendance_batch_id'
      and v_current ->> 'attendance_version' =
        v_attendance -> 'selected' ->> 'attendance_version'
      and v_current ->> 'attendance_approval_snapshot_id' =
        v_attendance -> 'selected' ->> 'attendance_approval_snapshot_id'
      and v_current ->> 'pantry_need_batch_id' =
        v_pantry -> 'selected' ->> 'pantry_need_batch_id'
      and v_current ->> 'pantry_need_batch_version' =
        v_pantry -> 'selected' ->> 'pantry_need_batch_version'
      and v_current ->> 'pantry_need_approval_snapshot_id' =
        v_pantry -> 'selected' ->> 'pantry_need_approval_snapshot_id'
      then 'CURRENT'
    else 'OUTDATED'
  end;

  return pg_catalog.jsonb_build_object(
    'period_start', period_start,
    'period_end', period_end,
    'readiness_state', case when v_blockers = 0
      and v_weekly ->> 'selection_state' = 'SELECTED'
      and v_attendance ->> 'selection_state' = 'SELECTED'
      and v_pantry ->> 'selection_state' = 'SELECTED'
      then 'READY' else 'BLOCKED' end,
    'source_evidence', pg_catalog.jsonb_build_object(
      'weekly_menu', v_weekly,
      'attendance', v_attendance,
      'pantry', v_pantry
    ),
    'issues', v_issues,
    'blocking_issue_count', v_blockers,
    'downstream_currentness', v_currentness,
    'current_need', v_current
  );
end;
$$;

revoke execute on function
  atlas_core.planning_contract_01_preflight_payload(date, date, jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.planning_contract_01_preflight_payload(date, date, jsonb)
to atlas_planning_command_runtime, atlas_need_generation_runtime,
  atlas_read_runtime;

reset role;
grant create on schema atlas_core to atlas_read_runtime;
alter function
  atlas_core.planning_contract_01_preflight_payload(date, date, jsonb)
owner to atlas_read_runtime;
revoke create on schema atlas_core from atlas_read_runtime;
set role atlas_owner;

grant create on schema atlas_api to atlas_read_runtime;
set role atlas_read_runtime;

create or replace function atlas_api.get_planning_input_preflight(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_planning_input_preflight';
  v_start date := atlas_core.rmvp_03b_safe_date(
    request -> 'payload' ->> 'period_start'
  );
  v_end date := atlas_core.rmvp_03b_safe_date(
    request -> 'payload' ->> 'period_end'
  );
  v_context jsonb;
begin
  if request ->> 'contract_version' is distinct from 'RMVP-03B.v2'
     or atlas_core.pa_05b_safe_uuid(
       request ->> 'requested_by_auth_subject'
     ) is null
     or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object'
     or v_start is null or v_end is null or v_end < v_start
     or (request -> 'payload') - array[
       'period_start', 'period_end', 'source_candidates'
     ] <> '{}'::jsonb then
    return pg_catalog.jsonb_build_object(
      'success', false, 'contract_version', 'RMVP-03B.v2',
      'error_code', 'VALIDATION_FAILED',
      'safe_message', 'The Planning preflight request is invalid.',
      'domain', 'PLANNING', 'read_name', v_name,
      'correlation_id', request ->> 'correlation_id'
    );
  end if;
  v_context := atlas_core.rmvp_03b_authorize_global(
    request, 'planning.inputs.read', v_name, true
  );
  if v_context ? 'error' then
    return (v_context -> 'error') ||
      pg_catalog.jsonb_build_object('contract_version', 'RMVP-03B.v2');
  end if;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-03B.v2',
    'correlation_id', request ->> 'correlation_id',
    'preflight', atlas_core.planning_contract_01_preflight_payload(
      v_start, v_end, request -> 'payload' -> 'source_candidates'
    ),
    'safe_operator_message',
      'Đã kiểm tra tự động dữ liệu nguồn cho kỳ lập nhu cầu.'
  );
exception when others then
  return pg_catalog.jsonb_build_object(
    'success', false, 'contract_version', 'RMVP-03B.v2',
    'error_code', 'INTERNAL_READ_FAILURE',
    'safe_message', 'Không thể kiểm tra dữ liệu nguồn một cách an toàn.',
    'domain', 'PLANNING', 'read_name', v_name,
    'correlation_id', request ->> 'correlation_id'
  );
end;
$$;

revoke execute on function atlas_api.get_planning_input_preflight(jsonb)
from public, anon, authenticated, service_role;
grant execute on function atlas_api.get_planning_input_preflight(jsonb)
to authenticated;
comment on function atlas_api.get_planning_input_preflight(jsonb) is
  'RMVP-03B.v2 automatic read-only source readiness and derived downstream currentness preflight.';

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime;

create or replace function atlas_core.planning_contract_01_prepare_top_command(
  request jsonb,
  command_name text,
  contract_version text,
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
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
begin
  v_error := atlas_core.planning_contract_01_validate_command(
    request, command_name, contract_version
  );
  if v_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_error
    );
  end if;
  v_actor_context := atlas_core.pa_05b_resolve_actor(
    request, 'PLANNING', command_name
  );
  if v_actor_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', (v_actor_context -> 'error') ||
        pg_catalog.jsonb_build_object('contract_version', contract_version)
    );
  end if;
  if v_actor_context ->> 'actor_type' <> 'HUMAN' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', atlas_core.planning_contract_01_command_error(
        request, command_name, contract_version,
        'DELEGATION_NOT_SUPPORTED',
        'Only an active authenticated human actor may use this command.'
      )
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');
  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, capability_code,
    'PLANNING', command_name, null, null, null
  );
  if v_authorization_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_authorization_error ||
        pg_catalog.jsonb_build_object('contract_version', contract_version)
    );
  end if;
  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, command_name, 'PLANNING', aggregate_scope
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_begin -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY', 'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

revoke execute on function
  atlas_core.planning_contract_01_prepare_top_command(
    jsonb, text, text, text, text
  )
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.planning_contract_01_prepare_top_command(
    jsonb, text, text, text, text
  )
to atlas_planning_command_runtime, atlas_need_generation_runtime;

grant create on schema atlas_api to atlas_planning_command_runtime;
set role atlas_planning_command_runtime;

create or replace function atlas_api.save_weekly_menu(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'save_weekly_menu';
  v_contract constant text := 'RMVP-03A.v2';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_menu atlas_planning.weekly_menus%rowtype;
  v_expected_signature text := pg_catalog.lower(coalesce(
    atlas_core.rmvp_03a_normalize_text(
      request -> 'payload' ->> 'expected_source_signature'
    ), ''
  ));
  v_claimed_signature text := pg_catalog.lower(coalesce(
    atlas_core.rmvp_03a_normalize_text(
      request -> 'payload' ->> 'source_signature'
    ), ''
  ));
  v_rows jsonb := atlas_core.rmvp_03a_canonical_menu_rows(
    request -> 'payload' -> 'rows'
  );
  v_derived_signature text;
  v_version bigint;
  v_legacy jsonb;
  v_result jsonb;
  v_error jsonb;
  v_recorded jsonb;
  v_preflight jsonb;
  v_prior_current jsonb;
  v_response jsonb;
begin
  if v_week_start is null
     or (request -> 'payload') - array[
       'week_start', 'source_type', 'source_name', 'source_signature',
       'expected_source_signature', 'rows'
     ] <> '{}'::jsonb
     or not (request -> 'payload' ?& array[
       'week_start', 'source_type', 'source_name', 'source_signature',
       'expected_source_signature', 'rows'
     ])
     or pg_catalog.jsonb_typeof(request -> 'payload' -> 'rows') <> 'array'
  then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'VALIDATION_FAILED',
      'The Weekly Menu completion payload is invalid.'
    );
  end if;
  v_derived_signature := atlas_core.rmvp_03a_menu_signature(v_rows);
  if v_claimed_signature = ''
     or v_claimed_signature <> v_derived_signature then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'CHECKSUM_MISMATCH',
      'Save requires the checksum of the complete canonical Weekly Menu.'
    );
  end if;
  v_prepare := atlas_core.planning_contract_01_prepare_top_command(
    request, v_name, v_contract, 'planning.weekly_menu.write',
    'weekly-menu:' || v_week_start::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return (v_prepare -> 'response') ||
      pg_catalog.jsonb_build_object('contract_version', v_contract);
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  begin
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_receipt_id', v_receipt_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_actor_id', v_actor_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_command_name', v_name, true
    );
    select candidate.current_need into v_prior_current
    from (
      select starts.day_offset, ends.day_offset as end_offset,
        atlas_core.planning_contract_01_current_need_payload(
          v_week_start + starts.day_offset,
          v_week_start + ends.day_offset
        ) as current_need
      from pg_catalog.generate_series(0, 6) starts(day_offset)
      cross join lateral pg_catalog.generate_series(
        starts.day_offset, 6
      ) ends(day_offset)
    ) candidate
    where candidate.current_need is not null
    order by candidate.day_offset, candidate.end_offset
    limit 1;
    select * into v_menu
    from atlas_planning.weekly_menus menu
    where menu.week_start = v_week_start
    for update;

    if found then
      if v_menu.version <> atlas_core.pa_05b_safe_bigint(
        request ->> 'expected_version'
      ) then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_VERSION',
          'Weekly Menu changed after it was read.', '[]'::jsonb,
          '[]'::jsonb, v_menu.version
        );
        raise sqlstate 'PC101' using message = 'Weekly Menu version is stale';
      end if;
      if v_expected_signature = ''
         or v_expected_signature <> v_menu.source_signature then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_SOURCE_SIGNATURE',
          'Weekly Menu source changed after it was read.'
        );
        raise sqlstate 'PC101' using message = 'Weekly Menu signature is stale';
      end if;
      v_version := v_menu.version;
      if v_menu.weekly_menu_status in (
        'APPROVED', 'NEED_GENERATION_REQUESTED'
      ) and v_menu.source_signature = v_derived_signature
        and v_menu.source_type = atlas_core.rmvp_03a_normalize_text(
          request -> 'payload' ->> 'source_type'
        )
        and v_menu.source_name = atlas_core.rmvp_03a_normalize_text(
          request -> 'payload' ->> 'source_name'
        ) then
        v_preflight := atlas_core.planning_contract_01_preflight_payload(
          v_week_start, v_week_start + 6, null
        );
        v_response := pg_catalog.jsonb_build_object(
          'success', true, 'contract_version', v_contract,
          'command_id', request ->> 'command_id',
          'correlation_id', request ->> 'correlation_id',
          'idempotency_status', 'NO_CHANGE',
          'affected_aggregate_ids', pg_catalog.jsonb_build_object(
            'weekly_menu_id', v_menu.weekly_menu_id,
            'weekly_menu_approval_snapshot_id',
              v_menu.latest_approval_snapshot_id
          ),
          'new_versions', pg_catalog.jsonb_build_object(
            'aggregate_version', v_menu.version
          ),
          'emitted_event_ids', '[]'::jsonb,
          'audit_event_ids', '[]'::jsonb,
          'authoritative_readback', pg_catalog.jsonb_build_object(
            'planning_inputs',
              atlas_core.rmvp_03a_planning_workbench_payload(v_week_start),
            'preflight', v_preflight
          ),
          'downstream_currentness',
            v_preflight ->> 'downstream_currentness',
          'safe_operator_message',
            'Thực đơn tuần đã hoàn tất và không có thay đổi.',
          'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
        );
        return atlas_core.planning_contract_01_finish_receipt(
          v_receipt_id, v_response, true
        );
      end if;
      if v_menu.weekly_menu_status in (
        'APPROVED', 'NEED_GENERATION_REQUESTED'
      ) then
        v_legacy := atlas_core.planning_contract_01_legacy_request(
          request, 'RMVP-03A.v1', v_menu.version,
          'SOURCE_CORRECTION',
          coalesce(nullif(pg_catalog.btrim(request ->> 'reason_note'), ''),
            'Lưu lại nguồn đã hoàn tất.'),
          pg_catalog.jsonb_build_object(
            'week_start', v_week_start,
            'expected_source_signature', v_menu.source_signature
          )
        );
        v_result := atlas_api.reopen_weekly_menu(v_legacy);
        if coalesce((v_result ->> 'success')::boolean, false) = false then
          v_error := v_result || pg_catalog.jsonb_build_object(
            'contract_version', v_contract, 'command_name', v_name
          );
          raise sqlstate 'PC101' using message = 'Weekly Menu reopen failed';
        end if;
        v_version := atlas_core.pa_05b_safe_bigint(
          v_result -> 'new_versions' ->> 'aggregate_version'
        );
      elsif v_menu.weekly_menu_status = 'VALIDATED'
        and v_menu.source_signature = v_derived_signature then
        v_version := v_menu.version;
      elsif v_menu.weekly_menu_status not in ('DRAFT', 'REOPENED') then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'INVALID_LIFECYCLE_STATE',
          'The current compatibility lifecycle state cannot accept a changed Save.'
        );
        raise sqlstate 'PC101' using message = 'Weekly Menu lifecycle state is invalid';
      else
        v_version := v_menu.version;
      end if;
    else
      if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
         or v_expected_signature <> '' then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_VERSION',
          'A new Weekly Menu starts at version 1 without a prior signature.'
        );
        raise sqlstate 'PC101' using message = 'New Weekly Menu expectation is stale';
      end if;
      v_version := 1;
    end if;

    if v_menu.weekly_menu_status is distinct from 'VALIDATED'
       or v_menu.source_signature is distinct from v_derived_signature then
      v_legacy := atlas_core.planning_contract_01_legacy_request(
        request, 'RMVP-03A.v1', v_version,
        'SOURCE_COMPLETION_SAVED', null,
        request -> 'payload'
      );
      v_result := atlas_api.save_weekly_menu_draft(v_legacy);
      if coalesce((v_result ->> 'success')::boolean, false) = false then
        v_error := v_result || pg_catalog.jsonb_build_object(
          'contract_version', v_contract, 'command_name', v_name
        );
        raise sqlstate 'PC101' using message = 'Weekly Menu save failed';
      end if;
      v_version := coalesce(atlas_core.pa_05b_safe_bigint(
        v_result -> 'new_versions' ->> 'aggregate_version'
      ), v_version);
      v_legacy := atlas_core.planning_contract_01_legacy_request(
        request, 'RMVP-03A.v1', v_version,
        'SOURCE_COMPLETION_VALIDATED', null,
        pg_catalog.jsonb_build_object('week_start', v_week_start)
      );
      v_result := atlas_api.validate_weekly_menu(v_legacy);
      if coalesce((v_result ->> 'success')::boolean, false) = false then
        v_error := v_result || pg_catalog.jsonb_build_object(
          'contract_version', v_contract, 'command_name', v_name
        );
        raise sqlstate 'PC101' using message = 'Weekly Menu validation failed';
      end if;
    end if;

    v_legacy := atlas_core.planning_contract_01_legacy_request(
      request, 'RMVP-03A.v1', v_version,
      'SOURCE_COMPLETION_APPROVED', null,
      pg_catalog.jsonb_build_object('week_start', v_week_start)
    );
    v_result := atlas_api.approve_weekly_menu(v_legacy);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC101' using message = 'Weekly Menu completion failed';
    end if;
    select * into v_menu from atlas_planning.weekly_menus menu
    where menu.week_start = v_week_start;
    v_recorded := atlas_core.rmvp_03a_record_change(
      request, v_actor_id, v_receipt_id, 'WeeklyMenuCompleted',
      'WeeklyMenu', v_menu.weekly_menu_id, v_menu.version, v_menu.version,
      pg_catalog.jsonb_build_object('status', 'WORKING'),
      pg_catalog.jsonb_build_object(
        'status', v_menu.weekly_menu_status,
        'approval_snapshot_id', v_menu.latest_approval_snapshot_id,
        'source_signature', v_menu.source_signature
      )
    );
    v_preflight := atlas_core.planning_contract_01_preflight_payload(
      v_week_start, v_week_start + 6, null
    );
    if v_prior_current is not null then
      v_preflight := pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          v_preflight, '{current_need}', v_prior_current, true
        ),
        '{downstream_currentness}', '"OUTDATED"'::jsonb, true
      );
    end if;
    v_response := pg_catalog.jsonb_build_object(
      'success', true, 'contract_version', v_contract,
      'command_id', request ->> 'command_id',
      'correlation_id', request ->> 'correlation_id',
      'idempotency_status', 'COMPLETED',
      'affected_aggregate_ids', pg_catalog.jsonb_build_object(
        'weekly_menu_id', v_menu.weekly_menu_id,
        'weekly_menu_approval_snapshot_id', v_menu.latest_approval_snapshot_id
      ),
      'new_versions', pg_catalog.jsonb_build_object(
        'aggregate_version', v_menu.version
      ),
      'emitted_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'domain_event_id'
      ),
      'audit_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'audit_event_id'
      ),
      'authoritative_readback', pg_catalog.jsonb_build_object(
        'planning_inputs',
          atlas_core.rmvp_03a_planning_workbench_payload(v_week_start),
        'preflight', v_preflight
      ),
      'downstream_currentness', v_preflight ->> 'downstream_currentness',
      'safe_operator_message',
        'Đã lưu và hoàn tất Thực đơn tuần trong một giao dịch.',
      'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
    );
  exception when sqlstate 'PC101' then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id, v_error, false
    );
  end;
  return atlas_core.planning_contract_01_finish_receipt(
    v_receipt_id, v_response, true
  );
exception when serialization_failure or deadlock_detected then
  if v_receipt_id is not null then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id,
      atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
        'Weekly Menu could not be locked safely. Retry the exact request.'
      ), false
    );
  end if;
  return atlas_core.planning_contract_01_command_error(
    request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Weekly Menu could not be locked safely. Retry the exact request.'
  );
when others then
  if v_receipt_id is not null then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id,
      atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
        'Weekly Menu could not be completed safely.'
      ), false
    );
  end if;
  return atlas_core.planning_contract_01_command_error(
    request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
    'Weekly Menu could not be completed safely.'
  );
end;
$$;

create or replace function atlas_api.save_attendance(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'save_attendance';
  v_contract constant text := 'RMVP-03A.v2';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_batch atlas_planning.attendance_batches%rowtype;
  v_expected_signature text := pg_catalog.lower(coalesce(
    atlas_core.rmvp_03a_normalize_text(
      request -> 'payload' ->> 'expected_source_signature'
    ), ''
  ));
  v_claimed_signature text := pg_catalog.lower(coalesce(
    atlas_core.rmvp_03a_normalize_text(
      request -> 'payload' ->> 'source_signature'
    ), ''
  ));
  v_rows jsonb := atlas_core.rmvp_03a_canonical_attendance_rows(
    request -> 'payload' -> 'rows'
  );
  v_derived_signature text;
  v_version bigint;
  v_legacy jsonb;
  v_result jsonb;
  v_error jsonb;
  v_recorded jsonb;
  v_preflight jsonb;
  v_prior_current jsonb;
  v_response jsonb;
begin
  if v_week_start is null
     or (request -> 'payload') - array[
       'week_start', 'source_type', 'source_name', 'source_signature',
       'expected_source_signature', 'rows'
     ] <> '{}'::jsonb
     or not (request -> 'payload' ?& array[
       'week_start', 'source_type', 'source_name', 'source_signature',
       'expected_source_signature', 'rows'
     ])
     or pg_catalog.jsonb_typeof(request -> 'payload' -> 'rows') <> 'array'
  then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'VALIDATION_FAILED',
      'The Attendance completion payload is invalid.'
    );
  end if;
  v_derived_signature := atlas_core.rmvp_03a_attendance_signature(v_rows);
  if v_claimed_signature = ''
     or v_claimed_signature <> v_derived_signature then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'CHECKSUM_MISMATCH',
      'Save requires the checksum of the complete canonical Attendance source.'
    );
  end if;
  v_prepare := atlas_core.planning_contract_01_prepare_top_command(
    request, v_name, v_contract, 'planning.attendance.write',
    'attendance:' || v_week_start::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return (v_prepare -> 'response') ||
      pg_catalog.jsonb_build_object('contract_version', v_contract);
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  begin
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_receipt_id', v_receipt_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_actor_id', v_actor_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_command_name', v_name, true
    );
    select candidate.current_need into v_prior_current
    from (
      select starts.day_offset, ends.day_offset as end_offset,
        atlas_core.planning_contract_01_current_need_payload(
          v_week_start + starts.day_offset,
          v_week_start + ends.day_offset
        ) as current_need
      from pg_catalog.generate_series(0, 6) starts(day_offset)
      cross join lateral pg_catalog.generate_series(
        starts.day_offset, 6
      ) ends(day_offset)
    ) candidate
    where candidate.current_need is not null
    order by candidate.day_offset, candidate.end_offset
    limit 1;
    select * into v_batch
    from atlas_planning.attendance_batches batch
    where batch.period_start = v_week_start
      and batch.period_end = v_week_start + 6
    for update;

    if found then
      if v_batch.version <> atlas_core.pa_05b_safe_bigint(
        request ->> 'expected_version'
      ) then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_VERSION',
          'Attendance changed after it was read.', '[]'::jsonb,
          '[]'::jsonb, v_batch.version
        );
        raise sqlstate 'PC102' using message = 'Attendance version is stale';
      end if;
      if v_expected_signature = ''
         or v_expected_signature <> v_batch.source_signature then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_SOURCE_SIGNATURE',
          'Attendance source changed after it was read.'
        );
        raise sqlstate 'PC102' using message = 'Attendance signature is stale';
      end if;
      v_version := v_batch.version;
      if v_batch.attendance_status in (
        'APPROVED', 'USED_FOR_NEED_GENERATION'
      ) and v_batch.source_signature = v_derived_signature
        and v_batch.source_type = atlas_core.rmvp_03a_normalize_text(
          request -> 'payload' ->> 'source_type'
        )
        and v_batch.source_name = atlas_core.rmvp_03a_normalize_text(
          request -> 'payload' ->> 'source_name'
        ) then
        v_preflight := atlas_core.planning_contract_01_preflight_payload(
          v_week_start, v_week_start + 6, null
        );
        v_response := pg_catalog.jsonb_build_object(
          'success', true, 'contract_version', v_contract,
          'command_id', request ->> 'command_id',
          'correlation_id', request ->> 'correlation_id',
          'idempotency_status', 'NO_CHANGE',
          'affected_aggregate_ids', pg_catalog.jsonb_build_object(
            'attendance_batch_id', v_batch.attendance_batch_id,
            'attendance_approval_snapshot_id',
              v_batch.latest_approval_snapshot_id
          ),
          'new_versions', pg_catalog.jsonb_build_object(
            'aggregate_version', v_batch.version
          ),
          'emitted_event_ids', '[]'::jsonb,
          'audit_event_ids', '[]'::jsonb,
          'authoritative_readback', pg_catalog.jsonb_build_object(
            'planning_inputs',
              atlas_core.rmvp_03a_planning_workbench_payload(v_week_start),
            'preflight', v_preflight
          ),
          'downstream_currentness',
            v_preflight ->> 'downstream_currentness',
          'safe_operator_message',
            'Số suất ăn đã hoàn tất và không có thay đổi.',
          'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
        );
        return atlas_core.planning_contract_01_finish_receipt(
          v_receipt_id, v_response, true
        );
      end if;
      if v_batch.attendance_status in (
        'APPROVED', 'USED_FOR_NEED_GENERATION'
      ) then
        v_legacy := atlas_core.planning_contract_01_legacy_request(
          request, 'RMVP-03A.v1', v_batch.version,
          'SOURCE_CORRECTION',
          coalesce(nullif(pg_catalog.btrim(request ->> 'reason_note'), ''),
            'Lưu lại nguồn đã hoàn tất.'),
          pg_catalog.jsonb_build_object(
            'week_start', v_week_start,
            'expected_source_signature', v_batch.source_signature
          )
        );
        v_result := atlas_api.reopen_attendance(v_legacy);
        if coalesce((v_result ->> 'success')::boolean, false) = false then
          v_error := v_result || pg_catalog.jsonb_build_object(
            'contract_version', v_contract, 'command_name', v_name
          );
          raise sqlstate 'PC102' using message = 'Attendance reopen failed';
        end if;
        v_version := atlas_core.pa_05b_safe_bigint(
          v_result -> 'new_versions' ->> 'aggregate_version'
        );
      elsif v_batch.attendance_status = 'VALIDATED'
        and v_batch.source_signature = v_derived_signature then
        v_version := v_batch.version;
      elsif v_batch.attendance_status not in ('DRAFT', 'REOPENED') then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'INVALID_LIFECYCLE_STATE',
          'The current compatibility lifecycle state cannot accept a changed Save.'
        );
        raise sqlstate 'PC102' using message = 'Attendance lifecycle state is invalid';
      else
        v_version := v_batch.version;
      end if;
    else
      if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
         or v_expected_signature <> '' then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_VERSION',
          'New Attendance starts at version 1 without a prior signature.'
        );
        raise sqlstate 'PC102' using message = 'New Attendance expectation is stale';
      end if;
      v_version := 1;
    end if;

    if v_batch.attendance_status is distinct from 'VALIDATED'
       or v_batch.source_signature is distinct from v_derived_signature then
      v_legacy := atlas_core.planning_contract_01_legacy_request(
        request, 'RMVP-03A.v1', v_version,
        'SOURCE_COMPLETION_SAVED', null,
        request -> 'payload'
      );
      v_result := atlas_api.save_attendance_draft(v_legacy);
      if coalesce((v_result ->> 'success')::boolean, false) = false then
        v_error := v_result || pg_catalog.jsonb_build_object(
          'contract_version', v_contract, 'command_name', v_name
        );
        raise sqlstate 'PC102' using message = 'Attendance save failed';
      end if;
      v_version := coalesce(atlas_core.pa_05b_safe_bigint(
        v_result -> 'new_versions' ->> 'aggregate_version'
      ), v_version);
      v_legacy := atlas_core.planning_contract_01_legacy_request(
        request, 'RMVP-03A.v1', v_version,
        'SOURCE_COMPLETION_VALIDATED', null,
        pg_catalog.jsonb_build_object('week_start', v_week_start)
      );
      v_result := atlas_api.validate_attendance(v_legacy);
      if coalesce((v_result ->> 'success')::boolean, false) = false then
        v_error := v_result || pg_catalog.jsonb_build_object(
          'contract_version', v_contract, 'command_name', v_name
        );
        raise sqlstate 'PC102' using message = 'Attendance validation failed';
      end if;
    end if;

    v_legacy := atlas_core.planning_contract_01_legacy_request(
      request, 'RMVP-03A.v1', v_version,
      'SOURCE_COMPLETION_APPROVED', null,
      pg_catalog.jsonb_build_object('week_start', v_week_start)
    );
    v_result := atlas_api.approve_attendance(v_legacy);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC102' using message = 'Attendance completion failed';
    end if;
    select * into v_batch from atlas_planning.attendance_batches batch
    where batch.period_start = v_week_start
      and batch.period_end = v_week_start + 6;
    v_recorded := atlas_core.rmvp_03a_record_change(
      request, v_actor_id, v_receipt_id, 'AttendanceCompleted',
      'AttendanceBatch', v_batch.attendance_batch_id,
      v_batch.version, v_batch.version,
      pg_catalog.jsonb_build_object('status', 'WORKING'),
      pg_catalog.jsonb_build_object(
        'status', v_batch.attendance_status,
        'approval_snapshot_id', v_batch.latest_approval_snapshot_id,
        'source_signature', v_batch.source_signature
      )
    );
    v_preflight := atlas_core.planning_contract_01_preflight_payload(
      v_week_start, v_week_start + 6, null
    );
    if v_prior_current is not null then
      v_preflight := pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          v_preflight, '{current_need}', v_prior_current, true
        ),
        '{downstream_currentness}', '"OUTDATED"'::jsonb, true
      );
    end if;
    v_response := pg_catalog.jsonb_build_object(
      'success', true, 'contract_version', v_contract,
      'command_id', request ->> 'command_id',
      'correlation_id', request ->> 'correlation_id',
      'idempotency_status', 'COMPLETED',
      'affected_aggregate_ids', pg_catalog.jsonb_build_object(
        'attendance_batch_id', v_batch.attendance_batch_id,
        'attendance_approval_snapshot_id',
          v_batch.latest_approval_snapshot_id
      ),
      'new_versions', pg_catalog.jsonb_build_object(
        'aggregate_version', v_batch.version
      ),
      'emitted_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'domain_event_id'
      ),
      'audit_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'audit_event_id'
      ),
      'authoritative_readback', pg_catalog.jsonb_build_object(
        'planning_inputs',
          atlas_core.rmvp_03a_planning_workbench_payload(v_week_start),
        'preflight', v_preflight
      ),
      'downstream_currentness', v_preflight ->> 'downstream_currentness',
      'safe_operator_message',
        'Đã lưu và hoàn tất Số suất ăn trong một giao dịch.',
      'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
    );
  exception when sqlstate 'PC102' then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id, v_error, false
    );
  end;
  return atlas_core.planning_contract_01_finish_receipt(
    v_receipt_id, v_response, true
  );
exception when serialization_failure or deadlock_detected then
  if v_receipt_id is not null then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id,
      atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
        'Attendance could not be locked safely. Retry the exact request.'
      ), false
    );
  end if;
  return atlas_core.planning_contract_01_command_error(
    request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Attendance could not be locked safely. Retry the exact request.'
  );
when others then
  if v_receipt_id is not null then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id,
      atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
        'Attendance could not be completed safely.'
      ), false
    );
  end if;
  return atlas_core.planning_contract_01_command_error(
    request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
    'Attendance could not be completed safely.'
  );
end;
$$;

create or replace function atlas_api.save_pantry(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  v_name constant text := 'save_pantry';
  v_contract constant text := 'PANTRY-02.v2';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_batch atlas_planning.pantry_need_batches%rowtype;
  v_expected_signature text := atlas_core.pantry_02_normalize_text(
    request -> 'payload' ->> 'expected_source_signature'
  );
  v_claimed_signature text := atlas_core.pantry_02_normalize_text(
    request -> 'payload' ->> 'source_signature'
  );
  v_no_additions boolean;
  v_rows jsonb;
  v_derived_signature text;
  v_version bigint;
  v_legacy jsonb;
  v_result jsonb;
  v_error jsonb;
  v_recorded jsonb;
  v_preflight jsonb;
  v_prior_current jsonb;
  v_response jsonb;
begin
  if v_week_start is null
     or (request -> 'payload') - array[
       'week_start', 'no_additions_confirmed', 'source_signature',
       'expected_source_signature', 'rows'
     ] <> '{}'::jsonb
     or not (request -> 'payload' ?& array[
       'week_start', 'no_additions_confirmed', 'source_signature',
       'expected_source_signature', 'rows'
     ])
     or pg_catalog.jsonb_typeof(
       request -> 'payload' -> 'no_additions_confirmed'
     ) <> 'boolean'
     or pg_catalog.jsonb_typeof(request -> 'payload' -> 'rows') <> 'array'
  then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'VALIDATION_FAILED',
      'The Pantry completion payload is invalid.'
    );
  end if;
  v_no_additions := (request -> 'payload' ->> 'no_additions_confirmed')::boolean;
  v_rows := atlas_core.pantry_02_canonical_rows(
    v_week_start, request -> 'payload' -> 'rows'
  );
  v_derived_signature := atlas_core.pantry_02_signature(
    v_week_start, v_no_additions, v_rows
  );
  if v_claimed_signature is null
     or v_claimed_signature is distinct from v_derived_signature then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'CHECKSUM_MISMATCH',
      'Save requires the checksum of the complete server-canonical Pantry source.'
    );
  end if;
  v_prepare := atlas_core.planning_contract_01_prepare_top_command(
    request, v_name, v_contract, 'planning.pantry.write',
    'pantry:' || v_week_start::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return (v_prepare -> 'response') ||
      pg_catalog.jsonb_build_object('contract_version', v_contract);
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  begin
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_receipt_id', v_receipt_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_actor_id', v_actor_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_command_name', v_name, true
    );
    select candidate.current_need into v_prior_current
    from (
      select starts.day_offset, ends.day_offset as end_offset,
        atlas_core.planning_contract_01_current_need_payload(
          v_week_start + starts.day_offset,
          v_week_start + ends.day_offset
        ) as current_need
      from pg_catalog.generate_series(0, 6) starts(day_offset)
      cross join lateral pg_catalog.generate_series(
        starts.day_offset, 6
      ) ends(day_offset)
    ) candidate
    where candidate.current_need is not null
    order by candidate.day_offset, candidate.end_offset
    limit 1;
    select * into v_batch
    from atlas_planning.pantry_need_batches batch
    where batch.week_start = v_week_start
    for update;

    if found then
      if v_batch.version <> atlas_core.pa_05b_safe_bigint(
        request ->> 'expected_version'
      ) then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_VERSION',
          'Pantry changed after it was read.', '[]'::jsonb,
          '[]'::jsonb, v_batch.version
        );
        raise sqlstate 'PC103' using message = 'Pantry version is stale';
      end if;
      if v_expected_signature is null
         or v_expected_signature is distinct from v_batch.source_signature then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_SOURCE_SIGNATURE',
          'Pantry source changed after it was read.'
        );
        raise sqlstate 'PC103' using message = 'Pantry signature is stale';
      end if;
      v_version := v_batch.version;
      if v_batch.pantry_need_batch_status = 'APPROVED'
         and v_batch.source_signature = v_derived_signature
         and v_batch.no_additions_confirmed = v_no_additions then
        v_preflight := atlas_core.planning_contract_01_preflight_payload(
          v_week_start, v_week_start + 6, null
        );
        v_response := pg_catalog.jsonb_build_object(
          'success', true, 'contract_version', v_contract,
          'command_id', request ->> 'command_id',
          'correlation_id', request ->> 'correlation_id',
          'idempotency_status', 'NO_CHANGE',
          'affected_aggregate_ids', pg_catalog.jsonb_build_object(
            'pantry_need_batch_id', v_batch.pantry_need_batch_id,
            'pantry_need_approval_snapshot_id',
              v_batch.latest_approval_snapshot_id
          ),
          'new_versions', pg_catalog.jsonb_build_object(
            'aggregate_version', v_batch.version
          ),
          'emitted_event_ids', '[]'::jsonb,
          'audit_event_ids', '[]'::jsonb,
          'authoritative_readback', pg_catalog.jsonb_build_object(
            'pantry', atlas_core.pantry_02_workbench_payload(
              v_week_start, v_actor_id
            ),
            'preflight', v_preflight
          ),
          'downstream_currentness',
            v_preflight ->> 'downstream_currentness',
          'safe_operator_message',
            'Nhu cầu bổ sung đã hoàn tất và không có thay đổi.',
          'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
        );
        return atlas_core.planning_contract_01_finish_receipt(
          v_receipt_id, v_response, true
        );
      end if;
      if v_batch.pantry_need_batch_status = 'APPROVED' then
        v_legacy := atlas_core.planning_contract_01_legacy_request(
          request, 'PANTRY-02.v1', v_version,
          'SOURCE_CORRECTION',
          coalesce(nullif(pg_catalog.btrim(request ->> 'reason_note'), ''),
            'Lưu lại nguồn đã hoàn tất.'),
          pg_catalog.jsonb_build_object(
            'week_start', v_week_start,
            'expected_source_signature', v_batch.source_signature
          )
        );
        v_result := atlas_api.reopen_pantry(v_legacy);
        if coalesce((v_result ->> 'success')::boolean, false) = false then
          v_error := v_result || pg_catalog.jsonb_build_object(
            'contract_version', v_contract, 'command_name', v_name
          );
          raise sqlstate 'PC103' using message = 'Pantry reopen failed';
        end if;
        v_version := atlas_core.pa_05b_safe_bigint(
          v_result -> 'new_versions' ->> 'pantry_need_batch_version'
        );
      elsif v_batch.pantry_need_batch_status = 'VALIDATED'
        and v_batch.source_signature = v_derived_signature then
        v_version := v_batch.version;
      elsif v_batch.pantry_need_batch_status not in ('DRAFT', 'REOPENED') then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'INVALID_LIFECYCLE_STATE',
          'The current compatibility lifecycle state cannot accept a changed Save.'
        );
        raise sqlstate 'PC103' using message = 'Pantry lifecycle state is invalid';
      else
        v_version := v_batch.version;
      end if;
    else
      if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
         or v_expected_signature is not null then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_VERSION',
          'A new Pantry week starts at version 1 without a prior signature.'
        );
        raise sqlstate 'PC103' using message = 'New Pantry expectation is stale';
      end if;
      v_version := 1;
    end if;

    if v_batch.pantry_need_batch_status is distinct from 'VALIDATED'
       or v_batch.source_signature is distinct from v_derived_signature then
      v_legacy := atlas_core.planning_contract_01_legacy_request(
        request, 'PANTRY-02.v1', v_version,
        'SOURCE_COMPLETION_SAVED', null,
        request -> 'payload'
      );
      v_result := atlas_api.save_pantry_draft(v_legacy);
      if coalesce((v_result ->> 'success')::boolean, false) = false then
        v_error := v_result || pg_catalog.jsonb_build_object(
          'contract_version', v_contract, 'command_name', v_name
        );
        raise sqlstate 'PC103' using message = 'Pantry save failed';
      end if;
      v_version := coalesce(atlas_core.pa_05b_safe_bigint(
        v_result -> 'new_versions' ->> 'pantry_need_batch_version'
      ), v_version);
      v_legacy := atlas_core.planning_contract_01_legacy_request(
        request, 'PANTRY-02.v1', v_version,
        'SOURCE_COMPLETION_VALIDATED', null,
        pg_catalog.jsonb_build_object(
          'week_start', v_week_start,
          'expected_source_signature', v_derived_signature
        )
      );
      v_result := atlas_api.validate_pantry(v_legacy);
      if coalesce((v_result ->> 'success')::boolean, false) = false then
        v_error := v_result || pg_catalog.jsonb_build_object(
          'contract_version', v_contract, 'command_name', v_name
        );
        raise sqlstate 'PC103' using message = 'Pantry validation failed';
      end if;
      v_version := coalesce(
        atlas_core.pa_05b_safe_bigint(
          v_result -> 'new_versions' ->> 'pantry_need_batch_version'
        ),
        v_version
      );
    end if;

    v_legacy := atlas_core.planning_contract_01_legacy_request(
      request, 'PANTRY-02.v1', v_version,
      'SOURCE_COMPLETION_APPROVED', null,
      pg_catalog.jsonb_build_object(
        'week_start', v_week_start,
        'expected_source_signature', v_derived_signature
      )
    );
    v_result := atlas_api.approve_pantry(v_legacy);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC103' using message = 'Pantry completion failed';
    end if;
    select * into v_batch from atlas_planning.pantry_need_batches batch
    where batch.week_start = v_week_start;
    v_recorded := atlas_core.pantry_02_record_change(
      'PantryCompleted', v_batch.pantry_need_batch_id,
      v_batch.version, v_batch.version, v_receipt_id,
      request, v_actor_id,
      pg_catalog.jsonb_build_object('status', 'WORKING'),
      pg_catalog.jsonb_build_object(
        'status', v_batch.pantry_need_batch_status,
        'approval_snapshot_id', v_batch.latest_approval_snapshot_id,
        'source_signature', v_batch.source_signature,
        'no_additions_confirmed', v_batch.no_additions_confirmed
      )
    );
    v_preflight := atlas_core.planning_contract_01_preflight_payload(
      v_week_start, v_week_start + 6, null
    );
    if v_prior_current is not null then
      v_preflight := pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          v_preflight, '{current_need}', v_prior_current, true
        ),
        '{downstream_currentness}', '"OUTDATED"'::jsonb, true
      );
    end if;
    v_response := pg_catalog.jsonb_build_object(
      'success', true, 'contract_version', v_contract,
      'command_id', request ->> 'command_id',
      'correlation_id', request ->> 'correlation_id',
      'idempotency_status', 'COMPLETED',
      'affected_aggregate_ids', pg_catalog.jsonb_build_object(
        'pantry_need_batch_id', v_batch.pantry_need_batch_id,
        'pantry_need_approval_snapshot_id',
          v_batch.latest_approval_snapshot_id
      ),
      'new_versions', pg_catalog.jsonb_build_object(
        'aggregate_version', v_batch.version
      ),
      'emitted_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'domain_event_id'
      ),
      'audit_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'audit_event_id'
      ),
      'authoritative_readback', pg_catalog.jsonb_build_object(
        'pantry', atlas_core.pantry_02_workbench_payload(
          v_week_start, v_actor_id
        ),
        'preflight', v_preflight
      ),
      'downstream_currentness', v_preflight ->> 'downstream_currentness',
      'safe_operator_message',
        'Đã lưu và hoàn tất Nhu cầu bổ sung trong một giao dịch.',
      'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
    );
  exception when sqlstate 'PC103' then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id, v_error, false
    );
  end;
  return atlas_core.planning_contract_01_finish_receipt(
    v_receipt_id, v_response, true
  );
exception when serialization_failure or deadlock_detected then
  if v_receipt_id is not null then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id,
      atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
        'Pantry could not be locked safely. Retry the exact request.'
      ), false
    );
  end if;
  return atlas_core.planning_contract_01_command_error(
    request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Pantry could not be locked safely. Retry the exact request.'
  );
when others then
  if v_receipt_id is not null then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id,
      atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
        'Pantry could not be completed safely.'
      ), false
    );
  end if;
  return atlas_core.planning_contract_01_command_error(
    request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
    'Pantry could not be completed safely.'
  );
end;
$$;

revoke execute on function
  atlas_api.save_weekly_menu(jsonb),
  atlas_api.save_attendance(jsonb),
  atlas_api.save_pantry(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_api.save_weekly_menu(jsonb),
  atlas_api.save_attendance(jsonb),
  atlas_api.save_pantry(jsonb)
to authenticated;

comment on function atlas_api.save_weekly_menu(jsonb) is
  'RMVP-03A.v2 consequential Weekly Menu Save: one source-specific receipt, full replacement, validation, and immutable completion snapshot.';
comment on function atlas_api.save_attendance(jsonb) is
  'RMVP-03A.v2 consequential Attendance Save: one source-specific receipt, stable rows, explicit zero portions, and immutable completion snapshot.';
comment on function atlas_api.save_pantry(jsonb) is
  'PANTRY-02.v2 consequential Pantry Save: one source-specific receipt, server-canonical replacement, and immutable completion snapshot.';

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_planning_command_runtime;
grant create on schema atlas_core, atlas_api
to atlas_planning_materialization_runtime;
set role atlas_planning_materialization_runtime;

create or replace function atlas_core.planning_contract_01_materialize_confirmed_needs(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'create_confirmed_needs_from_generation';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_internal jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_run_id uuid;
  v_run_version bigint;
  v_batch_id uuid;
  v_expected_version bigint;
  v_run atlas_planning.need_generation_runs%rowtype;
  v_old_run atlas_planning.need_generation_runs%rowtype;
  v_release atlas_planning.need_generation_release_snapshots%rowtype;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_initial boolean;
  v_active_count integer := 0;
  v_school_count integer := 0;
  v_group_count integer := 0;
  v_release_member_count integer := 0;
  v_created_line_count integer := 0;
  v_reused_line_count integer := 0;
  v_retired_line_count integer := 0;
  v_created_revision_count integer := 0;
  v_created_contribution_count integer := 0;
  v_current_revision_count integer := 0;
  v_superseded_revision_count integer := 0;
  v_old_current_count integer := 0;
  v_reused_old_count integer := 0;
  v_batch_version_before bigint;
  v_batch_version_after bigint;
  v_event_type text;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_counts jsonb;
  v_response jsonb;
begin
  v_error := atlas_core.pa_06e_h0cb_validate_materialization_request(request);
  if v_error is not null then return v_error; end if;

  v_run_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'need_generation_run_id');
  v_run_version := atlas_core.pa_05b_safe_bigint(v_payload ->> 'need_generation_run_version');
  v_batch_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id');
  v_expected_version := atlas_core.pa_05b_safe_bigint(request ->> 'expected_version');
  v_initial := v_batch_id is null;

  v_internal := atlas_core.planning_contract_01_internal_context(request);
  if v_internal is not null then
    v_actor_id := atlas_core.pa_05b_safe_uuid(v_internal ->> 'actor_id');
    v_receipt_id := atlas_core.pa_05b_safe_uuid(v_internal ->> 'receipt_id');
  else
    v_actor_context := atlas_core.pa_05b_resolve_actor(
      request, 'PLANNING', v_command_name
    );
    if v_actor_context ? 'error' then
      return v_actor_context -> 'error';
    end if;
    if v_actor_context ->> 'actor_type' <> 'HUMAN' then
      return atlas_core.pa_05b_command_error(
        request, 'DELEGATION_NOT_SUPPORTED',
        'Only an active authenticated human actor may materialize Confirmed Need.',
        'PLANNING', v_command_name
      );
    end if;
    v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');
  end if;

  select source_run.* into v_run
  from atlas_planning.need_generation_runs source_run
  where source_run.need_generation_run_id = v_run_id;
  if not found or v_run.run_status <> 'RELEASED_FOR_CONFIRMATION' then
    return atlas_core.pa_05b_command_error(
      request, 'GENERATION_NOT_RELEASED',
      'The requested Need Generation run is not released for confirmation.',
      'PLANNING', v_command_name
    );
  end if;
  if v_run.version <> v_run_version then
    return atlas_core.pa_05b_command_error(
      request, 'SOURCE_REVISION_STALE',
      'The requested Need Generation run version is stale.',
      'PLANNING', v_command_name, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
  end if;

  select release_snapshot.* into v_release
  from atlas_planning.need_generation_release_snapshots release_snapshot
  where release_snapshot.need_generation_run_id = v_run_id;
  if not found or v_release.released_run_version <> v_run_version then
    return atlas_core.pa_05b_command_error(
      request, 'GENERATION_NOT_RELEASED',
      'The exact immutable Need Generation release snapshot is unavailable.',
      'PLANNING', v_command_name
    );
  end if;

  if not v_initial then
    select target_batch.* into v_batch
    from atlas_planning.confirmed_need_batches target_batch
    where target_batch.confirmed_need_batch_id = v_batch_id;
    if not found or v_batch.source_kind <> 'NEED_GENERATION' then
      return atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED',
        'The requested Confirmed Need batch could not be validated.',
        'PLANNING', v_command_name
      );
    end if;
  end if;

  if v_internal is null then
    -- Reuse the common helper for capability and ordinary scope semantics. A
    -- SCOPE_DENIED result is refined below against the complete H0C four-kind
    -- scope set, including SCHOOL, which predates no generic PA-05B parameter.
    v_authorization_error := atlas_core.pa_05b_authorize_actor(
      request, v_actor_id, 'confirmed_need_generation.materialize',
      'PLANNING', v_command_name, null, null, null
    );
    if v_authorization_error is not null
       and v_authorization_error ->> 'error_code' <> 'SCOPE_DENIED' then
      return v_authorization_error;
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on not v_initial
       and old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
       and exists (
         select 1
         from atlas_planning.confirmed_need_line_revisions old_revision
         where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
           and old_revision.is_current
       )
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
        and not exists (
          select 1
          from atlas_core.actor_scopes scope
          where scope.actor_id = v_actor_id
            and scope.scope_status = 'ACTIVE'
            and scope.effective_from <= pg_catalog.transaction_timestamp()
            and (scope.effective_to is null or scope.effective_to > pg_catalog.transaction_timestamp())
            and (
              scope.scope_kind = 'GLOBAL'
              or (scope.scope_kind = 'CUSTOMER' and scope.customer_id = school.customer_id)
              or (scope.scope_kind = 'SCHOOL' and scope.school_id = school.school_id)
              or (
                scope.scope_kind = 'DELIVERY_LOCATION'
                and scope.delivery_location_id = case
                  when theoretical.contribution_family = 'PANTRY_DIRECT'
                    then theoretical.delivery_location_id
                  when old_contribution.delivery_location_id is not null
                    then old_contribution.delivery_location_id
                  else school.default_delivery_location_id
                end
              )
            )
        )
    ) then
      return atlas_core.pa_05b_command_error(
        request, 'SCOPE_DENIED',
        'The actor does not cover the complete released contribution set.',
        'PLANNING', v_command_name
      );
    end if;

  end if;

  if v_internal is null then
    v_begin := atlas_core.pa_05b_begin_command(
      request,
      v_actor_id,
      v_command_name,
      'PLANNING',
      case when v_initial
        then 'need-generation-run:' || v_run_id::text
        else 'confirmed-need-batch:' || v_batch_id::text
      end
    );
    if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
      return v_begin -> 'response';
    end if;
    v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  end if;

  perform pg_catalog.set_config('lock_timeout', '5s', true);
  perform pg_catalog.set_config('statement_timeout', '120s', true);

  -- Admin reference locks, always UUID ordered.
  perform 1
  from atlas_admin.customers customer
  where customer.customer_id in (
    select school.customer_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  )
  order by customer.customer_id for key share;
  perform 1
  from atlas_admin.schools school
  where school.school_id in (
    select theoretical.school_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  )
  order by school.school_id for key share;
  perform 1
  from atlas_admin.delivery_locations location
  where location.delivery_location_id in (
    select school.default_delivery_location_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    union
    select theoretical.delivery_location_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.contribution_family = 'PANTRY_DIRECT'
      and theoretical.line_disposition = 'ACTIVE'
    union
    select contribution.delivery_location_id
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
    where not v_initial
      and contribution.confirmed_need_batch_id = v_batch_id
      and revision.is_current
  )
  order by location.delivery_location_id for key share;
  perform 1
  from atlas_admin.ingredients ingredient
  where ingredient.ingredient_id in (
    select theoretical.ingredient_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  ) order by ingredient.ingredient_id for key share;
  perform 1
  from atlas_admin.units unit_record
  where unit_record.unit_id in (
    select theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  ) order by unit_record.unit_id for key share;

  -- Typed Recipe/source evidence precedes mutable Planning aggregate locks.
  perform 1 from atlas_planning.need_generation_input_snapshots snapshot
    where snapshot.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by snapshot.need_generation_input_snapshot_id for key share;
  perform 1 from atlas_planning.need_generation_recipe_selections selection
    where selection.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by selection.need_generation_recipe_selection_id for key share;
  perform 1 from atlas_planning.need_generation_recipe_line_uses recipe_use
    where recipe_use.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by recipe_use.need_generation_recipe_line_use_id for key share;

  perform 1 from atlas_planning.planning_input_sets input_set
    where input_set.planning_input_set_id = v_run.planning_input_set_id for key share;
  perform 1 from atlas_planning.planning_input_evaluations evaluation
    where evaluation.planning_input_set_id = v_run.planning_input_set_id
    order by evaluation.planning_input_evaluation_id for key share;
  perform 1 from atlas_planning.need_generation_runs source_run
    where source_run.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by source_run.need_generation_run_id for update;
  perform 1 from atlas_planning.need_generation_release_snapshots release_snapshot
    where release_snapshot.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by release_snapshot.need_generation_release_snapshot_id for key share;
  perform 1 from atlas_planning.need_generation_release_snapshot_lines release_line
    where release_line.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by release_line.need_generation_release_snapshot_line_id for key share;
  perform 1 from atlas_planning.theoretical_need_lines theoretical
    where theoretical.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by theoretical.theoretical_need_line_id for key share;

  if not v_initial then
    perform 1 from atlas_planning.confirmed_need_batches target_batch
      where target_batch.confirmed_need_batch_id = v_batch_id for update;
    perform 1 from atlas_planning.confirmed_need_lines target_line
      where target_line.confirmed_need_batch_id = v_batch_id
      order by target_line.confirmed_need_line_id for key share;
    perform 1 from atlas_planning.confirmed_need_line_revisions target_revision
      where target_revision.confirmed_need_batch_id = v_batch_id and target_revision.is_current
      order by target_revision.confirmed_need_line_revision_id for update;
  end if;

  -- Reread authoritative state after the deterministic lock set.
  select source_run.* into v_run
  from atlas_planning.need_generation_runs source_run
  where source_run.need_generation_run_id = v_run_id;
  select release_snapshot.* into v_release
  from atlas_planning.need_generation_release_snapshots release_snapshot
  where release_snapshot.need_generation_run_id = v_run_id;
  if v_run.run_status <> 'RELEASED_FOR_CONFIRMATION'
     or v_run.version <> v_run_version
     or v_release.released_run_version <> v_run_version
     or v_release.need_generation_input_snapshot_id <> v_run.input_snapshot_id then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_REVISION_STALE',
      'The released Need Generation source changed before materialization.',
      'PLANNING', v_command_name, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_release_member_count
  from atlas_planning.need_generation_release_snapshot_lines release_line
  where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id;
  select count(*)::integer into v_active_count
  from atlas_planning.need_generation_release_snapshot_lines release_line
  join atlas_planning.theoretical_need_lines theoretical
    on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
  where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    and theoretical.line_disposition = 'ACTIVE';

  if not exists (
    select 1 from atlas_planning.need_generation_input_snapshots snapshot
    where snapshot.need_generation_input_snapshot_id = v_run.input_snapshot_id
      and snapshot.need_generation_run_id = v_run_id
  ) or exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    left join atlas_planning.need_generation_recipe_selections selection
      on selection.need_generation_recipe_selection_id = theoretical.need_generation_recipe_selection_id
     and selection.need_generation_run_id = theoretical.need_generation_run_id
    left join atlas_planning.need_generation_recipe_line_uses recipe_use
      on recipe_use.need_generation_recipe_line_use_id = theoretical.need_generation_recipe_line_use_id
     and recipe_use.need_generation_run_id = theoretical.need_generation_run_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.contribution_family = 'RECIPE_DERIVED'
      and (selection.need_generation_recipe_selection_id is null or recipe_use.need_generation_recipe_line_use_id is null)
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_LINEAGE_INCOMPLETE',
      'The released source does not retain its complete typed input and contribution lineage.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_release_member_count <> v_release.generated_line_count
     or v_active_count <> v_release.active_line_count
     or v_release.generated_line_count <> v_release.active_line_count + v_release.removed_line_count then
    v_error := atlas_core.pa_05b_command_error(
      request, 'CONTRIBUTION_MEMBERSHIP_INVALID',
      'The immutable release membership does not match its released counts.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_active_count = 0
     and (
       v_initial
       or v_release_member_count = 0
       or exists (
         select 1
         from atlas_planning.need_generation_release_snapshot_lines release_line
         join atlas_planning.theoretical_need_lines theoretical
           on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
         where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
           and not (
             theoretical.contribution_family = 'PANTRY_DIRECT'
             and theoretical.line_disposition = 'REMOVED'
           )
       )
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'EMPTY_ACTIVE_RELEASE',
      'The released Need Generation result has no active contribution.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity = 0
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'ZERO_ACTIVE_CONTRIBUTION_POLICY_REQUIRED',
      'An active released contribution has zero quantity.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    left join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_admin.customers customer on customer.customer_id = school.customer_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on not v_initial
     and old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
     and exists (
       select 1
       from atlas_planning.confirmed_need_line_revisions old_revision
       where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
         and old_revision.is_current
     )
    left join atlas_admin.delivery_locations location
      on location.delivery_location_id = case
        when theoretical.contribution_family = 'PANTRY_DIRECT'
          then theoretical.delivery_location_id
        when old_contribution.delivery_location_id is not null
          then old_contribution.delivery_location_id
        else school.default_delivery_location_id
      end
     and location.customer_id = school.customer_id
    left join atlas_admin.ingredients ingredient on ingredient.ingredient_id = theoretical.ingredient_id
    left join atlas_admin.units unit_record on unit_record.unit_id = theoretical.unit_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and (
        theoretical.service_date < v_run.period_start
        or theoretical.service_date > v_run.period_end
        or school.school_status is distinct from 'ACTIVE'
        or school.customer_type is distinct from 'SCHOOL_CATERING'
        or customer.customer_type is distinct from 'SCHOOL_CATERING'
        or customer.customer_status is distinct from 'ACTIVE'
        or location.location_status is distinct from 'ACTIVE'
        or ingredient.ingredient_status is distinct from 'ACTIVE'
        or unit_record.unit_status is distinct from 'ACTIVE'
      )
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_MAPPING_INCOMPLETE',
      'The released contribution set has an inactive or inconsistent operational reference.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(distinct theoretical.school_id)::integer into v_school_count
  from atlas_planning.need_generation_release_snapshot_lines release_line
  join atlas_planning.theoretical_need_lines theoretical
    on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
  where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    and theoretical.line_disposition = 'ACTIVE';

  select count(*)::integer into v_group_count
  from (
    select theoretical.service_date, school.customer_id, theoretical.school_id,
           case
             when theoretical.contribution_family = 'PANTRY_DIRECT'
               then theoretical.delivery_location_id
             when old_contribution.delivery_location_id is not null
               then old_contribution.delivery_location_id
             else school.default_delivery_location_id
           end delivery_location_id,
           theoretical.ingredient_id, theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on not v_initial
     and old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
     and exists (
       select 1 from atlas_planning.confirmed_need_line_revisions old_revision
       where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
         and old_revision.is_current
     )
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    group by theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               when old_contribution.delivery_location_id is not null
                 then old_contribution.delivery_location_id
               else school.default_delivery_location_id
             end,
             theoretical.ingredient_id, theoretical.unit_id
  ) grouped;

  if (v_run.period_end - v_run.period_start + 1) > 14
     or v_school_count > 500
     or v_active_count > 25000
     or v_group_count > 15000 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'MATERIALIZATION_LIMIT_EXCEEDED',
      'The released result exceeds a bounded materialization limit.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_initial then
    if exists (
      select 1 from atlas_planning.confirmed_need_batches existing_batch
      where existing_batch.source_kind = 'NEED_GENERATION'
        and existing_batch.origin_need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'This released Need Generation result already has a Confirmed Need batch.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    insert into atlas_planning.confirmed_need_batches (
      wholesale_order_id,
      period_start,
      period_end,
      batch_status,
      version,
      created_by_actor_id,
      source_kind,
      origin_need_generation_run_id,
      origin_need_generation_run_version,
      origin_need_generation_release_snapshot_id,
      current_need_generation_run_id,
      current_need_generation_run_version,
      current_need_generation_release_snapshot_id
    ) values (
      null,
      v_run.period_start,
      v_run.period_end,
      'DRAFT_REVIEW',
      1,
      v_actor_id,
      'NEED_GENERATION',
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id
    ) returning confirmed_need_batch_id into v_batch_id;

    insert into atlas_planning.confirmed_need_lines (
      confirmed_need_batch_id,
      wholesale_order_line_id,
      source_kind,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      controlled_unit_id
    )
    select
      v_batch_id,
      null,
      'NEED_GENERATION',
      theoretical.service_date,
      school.customer_id,
      theoretical.school_id,
      case
        when theoretical.contribution_family = 'PANTRY_DIRECT'
          then theoretical.delivery_location_id
        else school.default_delivery_location_id
      end,
      theoretical.ingredient_id,
      theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    group by theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               else school.default_delivery_location_id
             end,
             theoretical.ingredient_id, theoretical.unit_id;
    get diagnostics v_created_line_count = row_count;

    insert into atlas_planning.confirmed_need_line_revisions (
      confirmed_need_line_id,
      revision_number,
      wholesale_order_line_revision_id,
      ingredient_id,
      theoretical_quantity,
      confirmed_quantity,
      unit_id,
      revision_status,
      is_current,
      predecessor_revision_id,
      command_id,
      created_by_actor_id,
      source_kind,
      confirmed_need_batch_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id
    )
    select
      target_line.confirmed_need_line_id,
      1,
      null,
      target_line.ingredient_id,
      sum(theoretical.theoretical_quantity),
      sum(theoretical.theoretical_quantity),
      target_line.controlled_unit_id,
      'DRAFT',
      true,
      null,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      v_actor_id,
      'NEED_GENERATION',
      v_batch_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      target_line.service_date,
      target_line.customer_id,
      target_line.school_id,
      target_line.delivery_location_id
    from atlas_planning.confirmed_need_lines target_line
    join atlas_planning.need_generation_release_snapshot_lines release_line
      on release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
     and theoretical.service_date = target_line.service_date
     and theoretical.school_id = target_line.school_id
    join atlas_admin.schools school
      on school.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       else school.default_delivery_location_id
     end
     and theoretical.ingredient_id = target_line.ingredient_id
     and theoretical.unit_id = target_line.controlled_unit_id
    where target_line.confirmed_need_batch_id = v_batch_id
      and target_line.source_kind = 'NEED_GENERATION'
    group by target_line.confirmed_need_line_id, target_line.ingredient_id,
             target_line.controlled_unit_id, target_line.service_date,
             target_line.customer_id, target_line.school_id, target_line.delivery_location_id;
    get diagnostics v_created_revision_count = row_count;

    insert into atlas_planning.confirmed_need_line_revision_contributions (
      confirmed_need_batch_id,
      confirmed_need_line_id,
      confirmed_need_line_revision_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      need_generation_release_snapshot_line_id,
      theoretical_need_line_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      source_unit_id,
      controlled_unit_id,
      source_theoretical_quantity,
      controlled_contribution_quantity
    )
    select
      v_batch_id,
      target_line.confirmed_need_line_id,
      target_revision.confirmed_need_line_revision_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      release_line.need_generation_release_snapshot_line_id,
      theoretical.theoretical_need_line_id,
      theoretical.service_date,
      target_line.customer_id,
      theoretical.school_id,
      target_line.delivery_location_id,
      theoretical.ingredient_id,
      theoretical.unit_id,
      target_line.controlled_unit_id,
      theoretical.theoretical_quantity,
      theoretical.theoretical_quantity
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
    join atlas_admin.schools school
      on school.school_id = theoretical.school_id
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.source_kind = 'NEED_GENERATION'
     and target_line.service_date = theoretical.service_date
     and target_line.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       else school.default_delivery_location_id
     end
     and target_line.ingredient_id = theoretical.ingredient_id
     and target_line.controlled_unit_id = theoretical.unit_id
    join atlas_planning.confirmed_need_line_revisions target_revision
      on target_revision.confirmed_need_line_id = target_line.confirmed_need_line_id
     and target_revision.is_current
     and target_revision.need_generation_run_id = v_run_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id;
    get diagnostics v_created_contribution_count = row_count;

    v_reused_line_count := 0;
    v_retired_line_count := 0;
    v_current_revision_count := v_created_revision_count;
    v_superseded_revision_count := 0;
    v_batch_version_before := null;
    v_batch_version_after := 1;
    v_event_type := 'ConfirmedNeedsCreated';
  else
    select target_batch.* into v_batch
    from atlas_planning.confirmed_need_batches target_batch
    where target_batch.confirmed_need_batch_id = v_batch_id;

    if v_batch.version <> v_expected_version then
      v_error := atlas_core.pa_05b_command_error(
        request, 'STALE_VERSION',
        'The Confirmed Need batch changed. Refresh before rematerialization.',
        'PLANNING', v_command_name, false, '[]'::jsonb,
        pg_catalog.jsonb_build_array(v_batch_id), v_batch.version
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
    if v_batch.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF' then
      v_error := atlas_core.pa_05b_command_error(
        request, 'DOWNSTREAM_CORRECTION_REQUIRED',
        'Released Confirmed Need requires an explicit downstream correction policy.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
    if v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then
      v_error := atlas_core.pa_05b_command_error(
        request, 'REOPEN_REQUIRED',
        'The Confirmed Need batch must be explicitly reopened before rematerialization.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    select prior_run.* into v_old_run
    from atlas_planning.need_generation_runs prior_run
    where prior_run.need_generation_run_id = v_batch.current_need_generation_run_id;
    if not found
       or not (
         v_batch.current_need_generation_run_version = v_old_run.version
         or (
           v_internal is not null
           and v_old_run.run_status = 'INVALIDATED'
           and v_old_run.version =
             v_batch.current_need_generation_run_version + 1
         )
       )
       or not exists (
         select 1 from atlas_planning.need_generation_release_snapshots old_release
         where old_release.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
           and old_release.need_generation_run_id = v_old_run.need_generation_run_id
           and old_release.released_run_version =
             v_batch.current_need_generation_run_version
       ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_REVISION_STALE',
        'The Confirmed Need batch current source is stale.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
    if v_run.predecessor_need_generation_run_id is distinct from v_old_run.need_generation_run_id
       or v_run.planning_input_set_id <> v_old_run.planning_input_set_id
       or v_run.period_start <> v_old_run.period_start
       or v_run.period_end <> v_old_run.period_end
       or v_batch.period_start <> v_run.period_start
       or v_batch.period_end <> v_run.period_end then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_SUCCESSOR_AMBIGUOUS',
        'The requested run is not the exact direct released successor of the batch current source.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines new_release_line
      join atlas_planning.theoretical_need_lines new_theoretical
        on new_theoretical.theoretical_need_line_id = new_release_line.theoretical_need_line_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = new_theoretical.predecessor_theoretical_need_line_id
      left join atlas_planning.confirmed_need_line_revisions old_revision
        on old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
       and old_revision.is_current
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and new_theoretical.line_disposition = 'ACTIVE'
        and new_theoretical.predecessor_theoretical_need_line_id is not null
        and (
          new_theoretical.predecessor_need_generation_run_id <> v_old_run.need_generation_run_id
          or old_contribution.confirmed_need_line_revision_contribution_id is null
          or old_revision.confirmed_need_line_revision_id is null
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_MAPPING_INCOMPLETE',
        'A successor contribution is not mapped to exactly one prior current contribution.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select old_contribution.theoretical_need_line_id
      from atlas_planning.confirmed_need_line_revision_contributions old_contribution
      join atlas_planning.confirmed_need_line_revisions old_revision
        on old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
      left join atlas_planning.theoretical_need_lines successor
        on successor.predecessor_theoretical_need_line_id = old_contribution.theoretical_need_line_id
       and successor.need_generation_run_id = v_run_id
      left join atlas_planning.need_generation_release_snapshot_lines successor_member
        on successor_member.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
       and successor_member.theoretical_need_line_id = successor.theoretical_need_line_id
      where old_contribution.confirmed_need_batch_id = v_batch_id
        and old_revision.is_current
      group by old_contribution.theoretical_need_line_id
      having count(successor_member.need_generation_release_snapshot_line_id) <> 1
         or count(successor_member.need_generation_release_snapshot_line_id)
              filter (
                where successor.line_disposition = 'ACTIVE'
                   or (
                     successor.contribution_family = 'PANTRY_DIRECT'
                     and successor.line_disposition = 'REMOVED'
                   )
              ) <> 1
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_REMOVAL_POLICY_REQUIRED',
        'A prior contribution lacks one accepted active or Pantry removal successor.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines new_release_line
      join atlas_planning.theoretical_need_lines successor
        on successor.theoretical_need_line_id = new_release_line.theoretical_need_line_id
      join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and successor.line_disposition = 'ACTIVE'
        and (
          successor.service_date <> old_contribution.service_date
          or successor.school_id <> old_contribution.school_id
          or successor.unit_id <> old_contribution.source_unit_id
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_SPLIT_MERGE_POLICY_REQUIRED',
        'The successor changes an operational fact across the no-conversion or split-merge boundary.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines new_release_line
      join atlas_planning.theoretical_need_lines successor
        on successor.theoretical_need_line_id = new_release_line.theoretical_need_line_id
      join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = successor.school_id
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and successor.line_disposition = 'ACTIVE'
        and successor.contribution_family = 'RECIPE_DERIVED'
        and school.default_delivery_location_id <> old_contribution.delivery_location_id
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'OPERATIONAL_IDENTITY_UNAPPROVED',
        'A School default destination changed for an existing contribution.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    select count(*)::integer into v_old_current_count
    from atlas_planning.confirmed_need_line_revisions old_revision
    where old_revision.confirmed_need_batch_id = v_batch_id
      and old_revision.is_current;
    if v_old_current_count = 0 or exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions old_revision
      where old_revision.confirmed_need_batch_id = v_batch_id
        and old_revision.is_current
        and row(
          old_revision.need_generation_run_id,
          old_revision.need_generation_run_version,
          old_revision.need_generation_release_snapshot_id
        ) is distinct from row(
          v_batch.current_need_generation_run_id,
          v_batch.current_need_generation_run_version,
          v_batch.current_need_generation_release_snapshot_id
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'CONTRIBUTION_MEMBERSHIP_INVALID',
        'The current Confirmed Need revision partition is incomplete or stale.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions old_revision
      where old_revision.confirmed_need_batch_id = v_batch_id
        and old_revision.is_current
        and old_revision.theoretical_quantity is distinct from (
          select sum(old_contribution.controlled_contribution_quantity)
          from atlas_planning.confirmed_need_line_revision_contributions old_contribution
          where old_contribution.confirmed_need_line_revision_id = old_revision.confirmed_need_line_revision_id
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'CONTRIBUTION_TOTAL_MISMATCH',
        'A current Confirmed Need revision does not equal its complete contribution membership.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    -- Add only genuinely absent stable identities; exact identities are reused.
    insert into atlas_planning.confirmed_need_lines (
      confirmed_need_batch_id,
      wholesale_order_line_id,
      source_kind,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      controlled_unit_id
    )
    select
      v_batch_id,
      null,
      'NEED_GENERATION',
      grouped.service_date,
      grouped.customer_id,
      grouped.school_id,
      grouped.delivery_location_id,
      grouped.ingredient_id,
      grouped.unit_id
    from (
      select theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               when old_contribution.delivery_location_id is not null
                 then old_contribution.delivery_location_id
               else school.default_delivery_location_id
             end delivery_location_id,
             theoretical.ingredient_id, theoretical.unit_id
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
      group by theoretical.service_date, school.customer_id, theoretical.school_id,
               case
                 when theoretical.contribution_family = 'PANTRY_DIRECT'
                   then theoretical.delivery_location_id
                 when old_contribution.delivery_location_id is not null
                   then old_contribution.delivery_location_id
                 else school.default_delivery_location_id
               end,
               theoretical.ingredient_id, theoretical.unit_id
    ) grouped
    where not exists (
      select 1 from atlas_planning.confirmed_need_lines existing_line
      where existing_line.confirmed_need_batch_id = v_batch_id
        and existing_line.source_kind = 'NEED_GENERATION'
        and existing_line.service_date = grouped.service_date
        and existing_line.customer_id = grouped.customer_id
        and existing_line.school_id = grouped.school_id
        and existing_line.delivery_location_id = grouped.delivery_location_id
        and existing_line.ingredient_id = grouped.ingredient_id
        and existing_line.controlled_unit_id = grouped.unit_id
    );
    get diagnostics v_created_line_count = row_count;
    v_reused_line_count := v_group_count - v_created_line_count;

    update atlas_planning.confirmed_need_line_revisions old_revision
    set revision_status = 'SUPERSEDED', is_current = false
    where old_revision.confirmed_need_batch_id = v_batch_id
      and old_revision.is_current;
    get diagnostics v_superseded_revision_count = row_count;

    insert into atlas_planning.confirmed_need_line_revisions (
      confirmed_need_line_id,
      revision_number,
      wholesale_order_line_revision_id,
      ingredient_id,
      theoretical_quantity,
      confirmed_quantity,
      unit_id,
      revision_status,
      is_current,
      predecessor_revision_id,
      command_id,
      created_by_actor_id,
      source_kind,
      confirmed_need_batch_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id
    )
    select
      target_line.confirmed_need_line_id,
      coalesce(prior_revision.revision_number + 1, 1),
      null,
      target_line.ingredient_id,
      grouped.theoretical_total,
      grouped.theoretical_total,
      target_line.controlled_unit_id,
      'DRAFT',
      true,
      prior_revision.confirmed_need_line_revision_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      v_actor_id,
      'NEED_GENERATION',
      v_batch_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      target_line.service_date,
      target_line.customer_id,
      target_line.school_id,
      target_line.delivery_location_id
    from (
      select theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               when old_contribution.delivery_location_id is not null
                 then old_contribution.delivery_location_id
               else school.default_delivery_location_id
             end delivery_location_id,
             theoretical.ingredient_id, theoretical.unit_id,
             sum(theoretical.theoretical_quantity) theoretical_total
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
      group by theoretical.service_date, school.customer_id, theoretical.school_id,
               case
                 when theoretical.contribution_family = 'PANTRY_DIRECT'
                   then theoretical.delivery_location_id
                 when old_contribution.delivery_location_id is not null
                   then old_contribution.delivery_location_id
                 else school.default_delivery_location_id
               end,
               theoretical.ingredient_id, theoretical.unit_id
    ) grouped
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.service_date = grouped.service_date
     and target_line.customer_id = grouped.customer_id
     and target_line.school_id = grouped.school_id
     and target_line.delivery_location_id = grouped.delivery_location_id
     and target_line.ingredient_id = grouped.ingredient_id
     and target_line.controlled_unit_id = grouped.unit_id
    left join lateral (
      select prior.confirmed_need_line_revision_id, prior.revision_number
      from atlas_planning.confirmed_need_line_revisions prior
      where prior.confirmed_need_line_id = target_line.confirmed_need_line_id
      order by prior.revision_number desc
      limit 1
    ) prior_revision on true;
    get diagnostics v_created_revision_count = row_count;

    insert into atlas_planning.confirmed_need_line_revision_contributions (
      confirmed_need_batch_id,
      confirmed_need_line_id,
      confirmed_need_line_revision_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      need_generation_release_snapshot_line_id,
      theoretical_need_line_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      source_unit_id,
      controlled_unit_id,
      source_theoretical_quantity,
      controlled_contribution_quantity
    )
    select
      v_batch_id,
      target_line.confirmed_need_line_id,
      target_revision.confirmed_need_line_revision_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      release_line.need_generation_release_snapshot_line_id,
      theoretical.theoretical_need_line_id,
      theoretical.service_date,
      target_line.customer_id,
      theoretical.school_id,
      target_line.delivery_location_id,
      theoretical.ingredient_id,
      theoretical.unit_id,
      target_line.controlled_unit_id,
      theoretical.theoretical_quantity,
      theoretical.theoretical_quantity
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.service_date = theoretical.service_date
     and target_line.customer_id = school.customer_id
     and target_line.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       when old_contribution.delivery_location_id is not null
         then old_contribution.delivery_location_id
       else school.default_delivery_location_id
     end
     and target_line.ingredient_id = theoretical.ingredient_id
     and target_line.controlled_unit_id = theoretical.unit_id
    join atlas_planning.confirmed_need_line_revisions target_revision
      on target_revision.confirmed_need_line_id = target_line.confirmed_need_line_id
     and target_revision.is_current
     and target_revision.need_generation_run_id = v_run_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id;
    get diagnostics v_created_contribution_count = row_count;

    select count(*)::integer into v_reused_old_count
    from atlas_planning.confirmed_need_line_revisions current_revision
    join atlas_planning.confirmed_need_line_revisions prior_revision
      on prior_revision.confirmed_need_line_revision_id = current_revision.predecessor_revision_id
    where current_revision.confirmed_need_batch_id = v_batch_id
      and current_revision.is_current
      and current_revision.need_generation_run_id = v_run_id
      and prior_revision.need_generation_run_id = v_old_run.need_generation_run_id;
    v_retired_line_count := v_old_current_count - v_reused_old_count;
    v_current_revision_count := v_created_revision_count;
    v_batch_version_before := v_batch.version;
    v_batch_version_after := v_batch.version + 1;
    v_event_type := 'ConfirmedNeedsRematerialized';

    update atlas_planning.confirmed_need_batches target_batch
    set current_need_generation_run_id = v_run_id,
        current_need_generation_run_version = v_run_version,
        current_need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id,
        version = v_batch_version_after,
        updated_at = pg_catalog.transaction_timestamp()
    where target_batch.confirmed_need_batch_id = v_batch_id;
  end if;

  v_counts := pg_catalog.jsonb_build_object(
    'created_confirmed_need_line_count', v_created_line_count,
    'reused_confirmed_need_line_count', v_reused_line_count,
    'retired_confirmed_need_line_count', v_retired_line_count,
    'created_line_revision_count', v_created_revision_count,
    'created_revision_contribution_count', v_created_contribution_count,
    'current_line_revision_count', v_current_revision_count,
    'superseded_line_revision_count', v_superseded_revision_count
  );

  insert into atlas_audit.domain_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    aggregate_version,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    occurred_at,
    payload_summary
  ) values (
    v_event_type,
    'PLANNING',
    'ConfirmedNeedBatch',
    v_batch_id,
    v_batch_version_after,
    v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'need_generation_run_id', v_run_id,
      'need_generation_run_version', v_run_version,
      'need_generation_release_snapshot_id', v_release.need_generation_release_snapshot_id,
      'service_period', pg_catalog.jsonb_build_object(
        'period_start', v_run.period_start,
        'period_end', v_run.period_end
      ),
      'result_counts', v_counts
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    aggregate_version_before,
    aggregate_version_after,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    reason_code,
    reason_note,
    before_summary,
    after_summary,
    source_interface,
    occurred_at
  ) values (
    v_event_type,
    'PLANNING',
    'ConfirmedNeedBatch',
    v_batch_id,
    v_batch_version_before,
    v_batch_version_after,
    v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,
    request ->> 'reason_code',
    request ->> 'reason_note',
    pg_catalog.jsonb_build_object(
      'batch_status', case when v_initial then null else v_batch.batch_status end,
      'version', v_batch_version_before,
      'current_source', case when v_initial then null else pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_batch.current_need_generation_run_id,
        'need_generation_run_version', v_batch.current_need_generation_run_version,
        'need_generation_release_snapshot_id', v_batch.current_need_generation_release_snapshot_id
      ) end,
      'result_counts', case when v_initial then null else pg_catalog.jsonb_build_object(
        'current_line_revision_count', v_old_current_count
      ) end
    ),
    pg_catalog.jsonb_build_object(
      'batch_status', 'DRAFT_REVIEW',
      'version', v_batch_version_after,
      'current_source', pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_run_id,
        'need_generation_run_version', v_run_version,
        'need_generation_release_snapshot_id', v_release.need_generation_release_snapshot_id
      ),
      'result_counts', v_counts
    ),
    'atlas_api',
    pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'need_generation_run_id', v_run_id,
      'confirmed_need_batch_id', v_batch_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'need_generation_run_version', v_run_version,
      'confirmed_need_batch_version', v_batch_version_after
    ),
    'result_counts', v_counts,
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', case when v_initial
      then 'Draft Confirmed Need created from the released generation result.'
      else 'Draft Confirmed Need rematerialized from the direct released successor.'
    end,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected or lock_not_available or query_canceled then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'PLANNING',
      v_command_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'Confirmed Need could not be materialized safely.',
      'PLANNING',
      v_command_name
    );
end;
$$;

create or replace function atlas_api.create_confirmed_needs_from_generation(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_response jsonb;
begin
  v_response := atlas_core.planning_contract_01_materialize_confirmed_needs(request);

  set constraints
    atlas_planning.confirmed_need_batches_current_source_consistency,
    atlas_planning.confirmed_need_lines_current_source_consistency,
    atlas_planning.confirmed_need_line_revisions_current_source_consistency,
    atlas_planning.confirmed_need_line_revisions_membership_total,
    atlas_planning.confirmed_need_line_revision_contributions_membership_total,
    atlas_planning.confirmed_need_lines_h1b1_decision_integrity,
    atlas_planning.confirmed_need_line_revisions_h1b1_decision_integrity,
    atlas_planning.confirmed_need_batches_validation_integrity
  immediate;

  set constraints
    atlas_planning.confirmed_need_batches_current_source_consistency,
    atlas_planning.confirmed_need_lines_current_source_consistency,
    atlas_planning.confirmed_need_line_revisions_current_source_consistency,
    atlas_planning.confirmed_need_line_revisions_membership_total,
    atlas_planning.confirmed_need_line_revision_contributions_membership_total,
    atlas_planning.confirmed_need_lines_h1b1_decision_integrity,
    atlas_planning.confirmed_need_line_revisions_h1b1_decision_integrity,
    atlas_planning.confirmed_need_batches_validation_integrity
  deferred;

  return v_response;
end;
$$;

revoke execute on function
  atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)
to atlas_need_generation_runtime, atlas_planning_materialization_runtime;
revoke execute on function
  atlas_api.create_confirmed_needs_from_generation(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_api.create_confirmed_needs_from_generation(jsonb)
to authenticated;
comment on function
  atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb) is
  'PLANNING-CONTRACT-01 single private H0C materialization algorithm shared by the PA-06E-H0C.v1 wrapper and RMVP-04.v2 execution.';
comment on function
  atlas_api.create_confirmed_needs_from_generation(jsonb) is
  'PA-06E-H0C.v1 compatibility wrapper delegating to the single private materialization algorithm.';

reset role;
set role atlas_owner;
revoke create on schema atlas_core, atlas_api
from atlas_planning_materialization_runtime;
set role atlas_planning_command_runtime;
grant execute on function
  atlas_api.evaluate_planning_input_readiness(jsonb),
  atlas_api.request_planning_input_need_generation(jsonb),
  atlas_api.invalidate_planning_input_readiness(jsonb)
to atlas_need_generation_runtime;
reset role;
set role atlas_owner;
grant execute on function
  atlas_core.rmvp_03b_stale_source_types(uuid, date, date)
to atlas_need_generation_runtime;
grant create on schema atlas_api to atlas_need_generation_runtime;
set role atlas_need_generation_runtime;

create or replace function atlas_api.execute_need_generation(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  v_name constant text := 'execute_need_generation';
  v_contract constant text := 'RMVP-04.v2';
  v_start date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'period_start'
  );
  v_end date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'period_end'
  );
  v_expected_run_id uuid := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'expected_current_need_generation_run_id'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_preflight jsonb;
  v_terminal atlas_planning.need_generation_runs%rowtype;
  v_set atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_run atlas_planning.need_generation_runs%rowtype;
  v_release atlas_planning.need_generation_release_snapshots%rowtype;
  v_stale_types jsonb := '[]'::jsonb;
  v_request_v1 jsonb;
  v_result jsonb;
  v_error jsonb;
  v_run_id uuid;
  v_run_version bigint;
  v_set_id uuid;
  v_evaluation_id uuid;
  v_evaluation_version bigint;
  v_recorded jsonb;
  v_response jsonb;
begin
  if v_start is null or v_end is null or v_end < v_start
     or v_end - v_start + 1 > 14
     or (request -> 'payload') - array[
       'period_start', 'period_end',
       'expected_current_need_generation_run_id'
     ] <> '{}'::jsonb
     or not (request -> 'payload' ?& array[
       'period_start', 'period_end',
       'expected_current_need_generation_run_id'
     ])
     or (
       request -> 'payload' -> 'expected_current_need_generation_run_id'
         <> 'null'::jsonb
       and v_expected_run_id is null
     ) then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'VALIDATION_FAILED',
      'The atomic Need Generation payload is invalid.'
    );
  end if;
  v_prepare := atlas_core.planning_contract_01_prepare_top_command(
    request, v_name, v_contract, 'planning.need_generation.write',
    'need-generation:' || v_start::text || ':' || v_end::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return (v_prepare -> 'response') ||
      pg_catalog.jsonb_build_object('contract_version', v_contract);
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  begin
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_receipt_id', v_receipt_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_actor_id', v_actor_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_command_name', v_name, true
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'PLANNING-CONTRACT-01:' || v_start::text || ':' || v_end::text, 0
      )
    );

    v_preflight := atlas_core.planning_contract_01_preflight_payload(
      v_start, v_end, null
    );
    if v_preflight ->> 'readiness_state' <> 'READY' then
      v_error := atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'PLANNING_INPUTS_NOT_READY',
        'Current completed Planning sources contain blocking issues.',
        '[]'::jsonb, v_preflight -> 'issues'
      );
      raise sqlstate 'PC104' using message = 'Planning preflight is blocked';
    end if;

    select run.* into v_terminal
    from atlas_planning.need_generation_runs run
    join atlas_planning.planning_input_sets input_set
      on input_set.planning_input_set_id = run.planning_input_set_id
    where input_set.period_start = v_start
      and input_set.period_end = v_end
    order by run.attempt_ordinal desc
    limit 1
    for update of run;

    if v_terminal.need_generation_run_id is null then
      if v_expected_run_id is not null
         or atlas_core.pa_05b_safe_bigint(
           request ->> 'expected_version'
         ) <> 1 then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_VERSION',
          'No current Need Generation run exists for the reviewed period.'
        );
        raise sqlstate 'PC104' using message = 'Need Generation expectation is stale';
      end if;
    elsif v_expected_run_id is distinct from
        v_terminal.need_generation_run_id
      or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <>
        v_terminal.version then
      v_error := atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'STALE_VERSION',
        'The current Need Generation run changed after preflight.',
        '[]'::jsonb,
        pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'need_generation_run_id', v_terminal.need_generation_run_id,
          'run_status', v_terminal.run_status
        )), v_terminal.version
      );
      raise sqlstate 'PC104' using message = 'Need Generation version is stale';
    end if;

    if v_preflight ->> 'downstream_currentness' = 'CURRENT' then
      v_response := pg_catalog.jsonb_build_object(
        'success', true, 'contract_version', v_contract,
        'command_id', request ->> 'command_id',
        'correlation_id', request ->> 'correlation_id',
        'idempotency_status', 'NO_CHANGE',
        'affected_aggregate_ids', pg_catalog.jsonb_build_object(
          'need_generation_run_id',
            v_preflight -> 'current_need' -> 'need_generation_run_id',
          'need_generation_release_snapshot_id',
            v_preflight -> 'current_need' ->
              'need_generation_release_snapshot_id',
          'confirmed_need_batch_id',
            v_preflight -> 'current_need' -> 'confirmed_need_batch_id'
        ),
        'new_versions', pg_catalog.jsonb_build_object(
          'need_generation_run_version',
            v_preflight -> 'current_need' -> 'need_generation_run_version',
          'confirmed_need_batch_version',
            v_preflight -> 'current_need' -> 'confirmed_need_batch_version'
        ),
        'emitted_event_ids', '[]'::jsonb,
        'audit_event_ids', '[]'::jsonb,
        'authoritative_readback', pg_catalog.jsonb_build_object(
          'preflight', v_preflight
        ),
        'downstream_currentness', 'CURRENT',
        'safe_operator_message',
          'Nhu cầu hiện tại đã khớp với toàn bộ dữ liệu nguồn.',
        'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
      );
      return atlas_core.planning_contract_01_finish_receipt(
        v_receipt_id, v_response, true
      );
    end if;

    if v_terminal.need_generation_run_id is not null
       and v_terminal.run_status <> 'INVALIDATED' then
      v_request_v1 := atlas_core.planning_contract_01_legacy_request(
        request, 'RMVP-04.v1', v_terminal.version,
        'UPSTREAM_SOURCE_CHANGED',
        coalesce(nullif(pg_catalog.btrim(request ->> 'reason_note'), ''),
          'Dữ liệu nguồn hoàn tất đã thay đổi.'),
        pg_catalog.jsonb_build_object(
          'need_generation_run_id', v_terminal.need_generation_run_id
        )
      );
      v_result := atlas_api.invalidate_need_generation_run(v_request_v1);
      if coalesce((v_result ->> 'success')::boolean, false) = false then
        v_error := v_result || pg_catalog.jsonb_build_object(
          'contract_version', v_contract, 'command_name', v_name
        );
        raise sqlstate 'PC104' using message = 'Prior generation invalidation failed';
      end if;
    end if;

    select input_set.* into v_set
    from atlas_planning.planning_input_sets input_set
    where input_set.period_start = v_start
      and input_set.period_end = v_end
    for update;
    if v_set.planning_input_set_id is not null then
      select evaluation.* into v_evaluation
      from atlas_planning.planning_input_evaluations evaluation
      where evaluation.planning_input_evaluation_id =
        v_set.current_evaluation_id;
      if v_set.readiness_status in ('READY', 'NEED_GENERATION_REQUESTED') then
        v_stale_types := atlas_core.rmvp_03b_stale_source_types(
          v_evaluation.planning_input_evaluation_id, v_start, v_end
        );
        v_request_v1 := pg_catalog.jsonb_build_object(
          'contract_version', 'RMVP-03B.v1',
          'command_id', request -> 'command_id',
          'correlation_id', request -> 'correlation_id',
          'idempotency_key', request -> 'idempotency_key',
          'requested_by_auth_subject', request -> 'requested_by_auth_subject',
          'requested_at', request -> 'requested_at',
          'expected_root_status', v_set.readiness_status,
          'expected_current_evaluation_id',
            v_evaluation.planning_input_evaluation_id,
          'expected_current_evaluation_version',
            v_evaluation.evaluation_version,
          'reason_code', case
            when pg_catalog.jsonb_array_length(v_stale_types) > 0
              then 'UPSTREAM_SOURCE_CHANGED'
            else 'PLANNING_REVIEW_CORRECTION' end,
          'reason_note', case
            when pg_catalog.jsonb_array_length(v_stale_types) > 0 then null
            else 'Tái đánh giá tự động trong lệnh tạo nhu cầu.' end,
          'payload', pg_catalog.jsonb_build_object(
            'planning_input_set_id', v_set.planning_input_set_id,
            'period_start', v_start, 'period_end', v_end
          )
        );
        v_result := atlas_api.invalidate_planning_input_readiness(v_request_v1);
        if coalesce((v_result ->> 'success')::boolean, false) = false then
          v_error := v_result || pg_catalog.jsonb_build_object(
            'contract_version', v_contract, 'command_name', v_name
          );
          raise sqlstate 'PC104' using message = 'Readiness invalidation failed';
        end if;
        select input_set.* into v_set
        from atlas_planning.planning_input_sets input_set
        where input_set.planning_input_set_id = v_set.planning_input_set_id;
      end if;
    end if;

    v_request_v1 := pg_catalog.jsonb_build_object(
      'contract_version', 'RMVP-03B.v1',
      'command_id', request -> 'command_id',
      'correlation_id', request -> 'correlation_id',
      'idempotency_key', request -> 'idempotency_key',
      'requested_by_auth_subject', request -> 'requested_by_auth_subject',
      'requested_at', request -> 'requested_at',
      'expected_root_status', coalesce(v_set.readiness_status, 'ABSENT'),
      'expected_current_evaluation_id', case
        when v_set.planning_input_set_id is null then null
        else v_set.current_evaluation_id end,
      'expected_current_evaluation_version', case
        when v_set.planning_input_set_id is null then null
        else (
          select evaluation.evaluation_version
          from atlas_planning.planning_input_evaluations evaluation
          where evaluation.planning_input_evaluation_id =
            v_set.current_evaluation_id
        ) end,
      'reason_code', 'READINESS_EVALUATION_REQUESTED',
      'reason_note', null,
      'payload', pg_catalog.jsonb_build_object(
        'period_start', v_start, 'period_end', v_end,
        'source_candidates', pg_catalog.jsonb_build_object(
          'weekly_menu', pg_catalog.jsonb_build_object(
            'weekly_menu_id', v_preflight -> 'source_evidence' ->
              'weekly_menu' -> 'selected' -> 'weekly_menu_id',
            'weekly_menu_version', v_preflight -> 'source_evidence' ->
              'weekly_menu' -> 'selected' -> 'weekly_menu_version',
            'weekly_menu_approval_snapshot_id',
              v_preflight -> 'source_evidence' -> 'weekly_menu' ->
                'selected' -> 'weekly_menu_approval_snapshot_id'
          ),
          'attendance', pg_catalog.jsonb_build_object(
            'attendance_batch_id', v_preflight -> 'source_evidence' ->
              'attendance' -> 'selected' -> 'attendance_batch_id',
            'attendance_version', v_preflight -> 'source_evidence' ->
              'attendance' -> 'selected' -> 'attendance_version',
            'attendance_approval_snapshot_id',
              v_preflight -> 'source_evidence' -> 'attendance' ->
                'selected' -> 'attendance_approval_snapshot_id'
          ),
          'pantry', pg_catalog.jsonb_build_object(
            'pantry_need_batch_id', v_preflight -> 'source_evidence' ->
              'pantry' -> 'selected' -> 'pantry_need_batch_id',
            'pantry_need_batch_version', v_preflight -> 'source_evidence' ->
              'pantry' -> 'selected' -> 'pantry_need_batch_version',
            'pantry_need_approval_snapshot_id',
              v_preflight -> 'source_evidence' -> 'pantry' ->
                'selected' -> 'pantry_need_approval_snapshot_id'
          )
        )
      )
    );
    v_result := atlas_api.evaluate_planning_input_readiness(v_request_v1);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Readiness evaluation failed';
    end if;
    v_set_id := atlas_core.pa_05b_safe_uuid(
      v_result -> 'affected_aggregate_ids' ->> 'planning_input_set_id'
    );
    v_evaluation_id := atlas_core.pa_05b_safe_uuid(
      v_result -> 'affected_aggregate_ids' ->>
        'planning_input_evaluation_id'
    );
    v_evaluation_version := atlas_core.pa_05b_safe_bigint(
      v_result -> 'new_versions' ->> 'current_evaluation_version'
    );

    v_request_v1 := pg_catalog.jsonb_build_object(
      'contract_version', 'RMVP-03B.v1',
      'command_id', request -> 'command_id',
      'correlation_id', request -> 'correlation_id',
      'idempotency_key', request -> 'idempotency_key',
      'requested_by_auth_subject', request -> 'requested_by_auth_subject',
      'requested_at', request -> 'requested_at',
      'expected_root_status', 'READY',
      'expected_current_evaluation_id', v_evaluation_id,
      'expected_current_evaluation_version', v_evaluation_version,
      'reason_code', 'NEED_GENERATION_HANDOFF_REQUESTED',
      'reason_note', null,
      'payload', pg_catalog.jsonb_build_object(
        'planning_input_set_id', v_set_id,
        'period_start', v_start, 'period_end', v_end
      )
    );
    v_result := atlas_api.request_planning_input_need_generation(v_request_v1);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Readiness handoff failed';
    end if;

    v_request_v1 := atlas_core.planning_contract_01_legacy_request(
      request, 'RMVP-04.v1', v_evaluation_version,
      'NEED_GENERATION_CREATED', null,
      pg_catalog.jsonb_build_object(
        'planning_input_set_id', v_set_id,
        'planning_input_evaluation_id', v_evaluation_id,
        'period_start', v_start, 'period_end', v_end
      )
    );
    v_result := atlas_api.create_need_generation_run(v_request_v1);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Need Generation creation failed';
    end if;
    v_run_id := atlas_core.pa_05b_safe_uuid(
      v_result -> 'affected_aggregate_ids' ->> 'need_generation_run_id'
    );
    v_run_version := atlas_core.pa_05b_safe_bigint(
      v_result -> 'new_versions' ->> 'need_generation_run_version'
    );

    v_request_v1 := atlas_core.planning_contract_01_legacy_request(
      request, 'RMVP-04.v1', v_run_version,
      'NEED_GENERATION_VALIDATED', null,
      pg_catalog.jsonb_build_object('need_generation_run_id', v_run_id)
    );
    v_result := atlas_api.validate_need_generation_run(v_request_v1);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Need Generation integrity validation failed';
    end if;
    v_run_version := atlas_core.pa_05b_safe_bigint(
      v_result -> 'new_versions' ->> 'need_generation_run_version'
    );

    v_request_v1 := atlas_core.planning_contract_01_legacy_request(
      request, 'RMVP-04.v1', v_run_version,
      'NEED_GENERATION_RELEASED', null,
      pg_catalog.jsonb_build_object('need_generation_run_id', v_run_id)
    );
    v_result := atlas_api.release_need_generation_run(v_request_v1);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Need Generation release failed';
    end if;
    v_run_version := atlas_core.pa_05b_safe_bigint(
      v_result -> 'new_versions' ->> 'need_generation_run_version'
    );

    select batch.* into v_batch
    from atlas_planning.confirmed_need_batches batch
    where batch.source_kind = 'NEED_GENERATION'
      and batch.period_start = v_start and batch.period_end = v_end
    order by batch.updated_at desc, batch.confirmed_need_batch_id
    limit 1
    for update;
    v_request_v1 := atlas_core.planning_contract_01_legacy_request(
      request, 'PA-06E-H0C.v1',
      coalesce(v_batch.version, 1),
      case when v_batch.confirmed_need_batch_id is null
        then 'CONFIRMED_NEED_MATERIALIZED'
        else 'CONFIRMED_NEED_CORRECTED' end,
      null,
      pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_run_id,
        'need_generation_run_version', v_run_version,
        'confirmed_need_batch_id', v_batch.confirmed_need_batch_id
      )
    );
    v_result := atlas_core.planning_contract_01_materialize_confirmed_needs(
      v_request_v1
    );
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Confirmed Need materialization failed';
    end if;

    -- Flush the private materializer's deferred cross-aggregate guards while
    -- the released run and its Confirmed Need pointer are mutually current.
    -- This keeps a later correction from rechecking an obsolete queued event
    -- after the predecessor has been deliberately invalidated.
    set constraints all immediate;
    set constraints all deferred;

    select run.* into v_run
    from atlas_planning.need_generation_runs run
    where run.need_generation_run_id = v_run_id;
    select release_snapshot.* into v_release
    from atlas_planning.need_generation_release_snapshots release_snapshot
    where release_snapshot.need_generation_run_id = v_run_id;
    select batch.* into v_batch
    from atlas_planning.confirmed_need_batches batch
    where batch.confirmed_need_batch_id = atlas_core.pa_05b_safe_uuid(
      v_result -> 'affected_aggregate_ids' ->> 'confirmed_need_batch_id'
    );
    v_recorded := atlas_core.rmvp_04_record_change(
      request, v_actor_id, v_receipt_id, 'NeedGenerationExecuted',
      v_run_id, v_run.version, v_run.version,
      pg_catalog.jsonb_build_object(
        'downstream_currentness',
          v_preflight ->> 'downstream_currentness'
      ),
      pg_catalog.jsonb_build_object(
        'run_status', v_run.run_status,
        'release_snapshot_id',
          v_release.need_generation_release_snapshot_id,
        'confirmed_need_batch_id', v_batch.confirmed_need_batch_id,
        'confirmed_need_batch_version', v_batch.version
      )
    );
    v_preflight := atlas_core.planning_contract_01_preflight_payload(
      v_start, v_end, null
    );
    if v_preflight ->> 'downstream_currentness' <> 'CURRENT' then
      v_error := atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'INVARIANT_VIOLATION',
        'The committed Need result did not become current.'
      );
      raise sqlstate 'PC104' using message = 'Committed generation is not current';
    end if;
    v_response := pg_catalog.jsonb_build_object(
      'success', true, 'contract_version', v_contract,
      'command_id', request ->> 'command_id',
      'correlation_id', request ->> 'correlation_id',
      'idempotency_status', 'COMPLETED',
      'affected_aggregate_ids', pg_catalog.jsonb_build_object(
        'planning_input_set_id', v_set_id,
        'planning_input_evaluation_id', v_evaluation_id,
        'need_generation_run_id', v_run_id,
        'need_generation_release_snapshot_id',
          v_release.need_generation_release_snapshot_id,
        'confirmed_need_batch_id', v_batch.confirmed_need_batch_id
      ),
      'new_versions', pg_catalog.jsonb_build_object(
        'need_generation_run_version', v_run.version,
        'confirmed_need_batch_version', v_batch.version
      ),
      'result_counts', v_result -> 'result_counts',
      'emitted_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'domain_event_id'
      ),
      'audit_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'audit_event_id'
      ),
      'authoritative_readback', pg_catalog.jsonb_build_object(
        'preflight', v_preflight,
        'need_generation', atlas_core.rmvp_04_workbench_payload(
          v_start, v_end, v_run_id, '{}'::jsonb, 0, 100, null
        )
      ),
      'downstream_currentness', 'CURRENT',
      'safe_operator_message', case
        when v_terminal.need_generation_run_id is null
          then 'Đã tạo nhu cầu và Phiếu nhu cầu xác nhận trong một giao dịch.'
        else 'Đã cập nhật nhu cầu và hiệu chỉnh Phiếu nhu cầu xác nhận trong một giao dịch.'
      end,
      'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
    );
  exception when sqlstate 'PC104' then
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id, v_error, false
    );
  end;
  return atlas_core.planning_contract_01_finish_receipt(
    v_receipt_id, v_response, true
  );
exception
  when serialization_failure or deadlock_detected
    or lock_not_available or query_canceled then
    if v_receipt_id is not null then
      return atlas_core.planning_contract_01_finish_receipt(
        v_receipt_id,
        atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
          'Need Generation could not acquire a safe transaction state. Retry the exact request.'
        ), false
      );
    end if;
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
      'Need Generation could not acquire a safe transaction state. Retry the exact request.'
    );
  when others then
    if v_receipt_id is not null then
      return atlas_core.planning_contract_01_finish_receipt(
        v_receipt_id,
        atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
          'Need Generation could not be executed atomically.'
        ), false
      );
    end if;
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
      'Need Generation could not be executed atomically.'
    );
end;
$$;

revoke execute on function atlas_api.execute_need_generation(jsonb)
from public, anon, authenticated, service_role;
grant execute on function atlas_api.execute_need_generation(jsonb)
to authenticated;
comment on function atlas_api.execute_need_generation(jsonb) is
  'RMVP-04.v2 one-receipt atomic readiness, generation, deterministic validation, immutable release, and H0C materialization/correction command.';

reset role;
revoke atlas_planning_command_runtime, atlas_need_generation_runtime,
  atlas_planning_materialization_runtime, atlas_read_runtime
from postgres;
set role atlas_owner;
revoke create on schema atlas_api from atlas_need_generation_runtime;
comment on schema atlas_api is
  'Function-only Atlas Data API boundary including additive D-036 Planning completion, automatic preflight, and atomic Need Generation contracts.';

revoke create on schema atlas_core
from atlas_planning_command_runtime, atlas_need_generation_runtime;
reset role;
