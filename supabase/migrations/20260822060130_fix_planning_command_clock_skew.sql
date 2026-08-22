-- Issue #215
-- Planning v2 accepts at most 60 seconds of positive client clock skew.
-- After the public envelope passes, every server-derived legacy/readiness
-- command uses the authoritative transaction timestamp. Public v1 validators
-- and Confirmed Need v2 timestamp semantics remain unchanged.

reset role;
grant atlas_planning_command_runtime, atlas_need_generation_runtime,
  atlas_planning_materialization_runtime, atlas_read_runtime
to postgres with set true;

set role atlas_owner;

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
     or v_requested_at > pg_catalog.transaction_timestamp()
       + pg_catalog.interval '60 seconds' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_at',
        'message', 'A valid timestamp within 60 seconds of server time is required.'
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
    'requested_at', pg_catalog.to_jsonb(pg_catalog.transaction_timestamp()),
    'reason_code', reason_code,
    'reason_note', pg_catalog.to_jsonb(reason_note),
    'payload', payload
  );
$$;

reset role;
set role atlas_owner;
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
          'requested_at', pg_catalog.to_jsonb(pg_catalog.transaction_timestamp()),
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
      'requested_at', pg_catalog.to_jsonb(pg_catalog.transaction_timestamp()),
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
      'requested_at', pg_catalog.to_jsonb(pg_catalog.transaction_timestamp()),
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

reset role;
revoke atlas_planning_command_runtime, atlas_need_generation_runtime,
  atlas_planning_materialization_runtime, atlas_read_runtime
from postgres;
set role atlas_owner;
revoke create on schema atlas_api from atlas_need_generation_runtime;
reset role;
