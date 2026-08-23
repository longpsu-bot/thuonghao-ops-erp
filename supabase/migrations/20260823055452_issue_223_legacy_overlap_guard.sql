-- ISSUE-223 root-review correction: one service date cannot start a new daily
-- Need chain while an active historical multi-day Need chain contains it.
-- Historical rows remain untouched. Public RMVP-04.v2 is retained only for
-- exact D..D compatibility; its former arbitrary-period implementation stays
-- private for controlled internal/historical compatibility.

grant atlas_read_runtime, atlas_need_generation_runtime to postgres with set true;

set role atlas_owner;
grant create on schema atlas_core to atlas_read_runtime;
grant create on schema atlas_api to atlas_need_generation_runtime;
create index need_generation_runs_active_multiday_period_idx
  on atlas_planning.need_generation_runs (period_start, period_end)
  where run_status <> 'INVALIDATED' and period_start < period_end;
reset role;

set role atlas_read_runtime;

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
  v_payload jsonb := atlas_core.issue_223_period_preflight_payload(
    period_start, period_end, supplied_candidates
  );
  v_current jsonb := v_payload -> 'current_need';
  v_sources jsonb := v_payload -> 'source_evidence';
  v_current_fingerprints jsonb;
  v_selected_fingerprints jsonb;
  v_currentness text;
  v_legacy_chains jsonb;
  v_legacy_overlap jsonb;
  v_overlap_issue jsonb;
begin
  if period_start is distinct from period_end then
    return v_payload;
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'need_generation_run_id', legacy.need_generation_run_id,
        'need_generation_run_status', legacy.run_status,
        'need_generation_run_version', legacy.run_version,
        'period_start', legacy.period_start,
        'period_end', legacy.period_end,
        'confirmed_need_batch_id', legacy.confirmed_need_batch_id,
        'confirmed_need_batch_status', legacy.confirmed_need_batch_status,
        'confirmed_need_batch_version', legacy.confirmed_need_batch_version
      ) order by legacy.period_start, legacy.period_end,
        legacy.need_generation_run_id
    ), '[]'::jsonb
  )
  into v_legacy_chains
  from (
    select
      run.need_generation_run_id,
      run.run_status,
      run.version as run_version,
      run.period_start,
      run.period_end,
      batch.confirmed_need_batch_id,
      batch.batch_status as confirmed_need_batch_status,
      batch.version as confirmed_need_batch_version
    from atlas_planning.need_generation_runs run
    left join atlas_planning.confirmed_need_batches batch
      on batch.source_kind = 'NEED_GENERATION'
     and batch.current_need_generation_run_id = run.need_generation_run_id
    where run.period_start < run.period_end
      and run.period_start <= planning_contract_01_preflight_payload.period_start
      and run.period_end >= planning_contract_01_preflight_payload.period_start
      and run.run_status <> 'INVALIDATED'
  ) legacy;

  if pg_catalog.jsonb_array_length(v_legacy_chains) > 0 then
    v_legacy_overlap := pg_catalog.jsonb_build_object(
      'service_date', period_start,
      'blocker_code', 'ACTIVE_LEGACY_NEED_RANGE_OVERLAP',
      'safe_message',
        'An active historical multi-day Need commitment contains this service date.',
      'active_chains', v_legacy_chains
    );
    v_overlap_issue := pg_catalog.jsonb_build_object(
      'severity', 'BLOCKING',
      'issue_code', 'ACTIVE_LEGACY_NEED_RANGE_OVERLAP',
      'message',
        'An active historical multi-day Need commitment contains this service date.',
      'input_type', 'NEED_GENERATION',
      'school_id', null,
      'service_date', period_start,
      'legacy_overlap', v_legacy_overlap
    );
    v_payload := pg_catalog.jsonb_set(
      pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          pg_catalog.jsonb_set(
            v_payload, '{readiness_state}', '"BLOCKED"'::jsonb, true
          ),
          '{downstream_currentness}', '"LEGACY_OVERLAP"'::jsonb, true
        ),
        '{issues}',
        coalesce(v_payload -> 'issues', '[]'::jsonb)
          || pg_catalog.jsonb_build_array(v_overlap_issue),
        true
      ),
      '{blocking_issue_count}',
      pg_catalog.to_jsonb(
        coalesce(
          atlas_core.pa_05b_safe_bigint(
            v_payload ->> 'blocking_issue_count'
          ), 0
        ) + 1
      ), true
    );
    return pg_catalog.jsonb_set(
      v_payload, '{legacy_overlap}', v_legacy_overlap, true
    );
  end if;

  if pg_catalog.current_setting(
       'atlas.issue_223_period_compatibility', true
     ) = 'true' then
    return v_payload;
  end if;

  v_current_fingerprints := pg_catalog.jsonb_build_object(
    'weekly_menu', atlas_core.issue_223_source_date_fingerprint(
      'WEEKLY_MENU', atlas_core.pa_05b_safe_uuid(
        v_current ->> 'weekly_menu_approval_snapshot_id'
      ), period_start
    ),
    'attendance', atlas_core.issue_223_source_date_fingerprint(
      'ATTENDANCE', atlas_core.pa_05b_safe_uuid(
        v_current ->> 'attendance_approval_snapshot_id'
      ), period_start
    ),
    'pantry', atlas_core.issue_223_source_date_fingerprint(
      'PANTRY', atlas_core.pa_05b_safe_uuid(
        v_current ->> 'pantry_need_approval_snapshot_id'
      ), period_start
    )
  );
  v_selected_fingerprints := pg_catalog.jsonb_build_object(
    'weekly_menu', atlas_core.issue_223_source_date_fingerprint(
      'WEEKLY_MENU', atlas_core.pa_05b_safe_uuid(
        v_sources -> 'weekly_menu' -> 'selected' ->>
          'weekly_menu_approval_snapshot_id'
      ), period_start
    ),
    'attendance', atlas_core.issue_223_source_date_fingerprint(
      'ATTENDANCE', atlas_core.pa_05b_safe_uuid(
        v_sources -> 'attendance' -> 'selected' ->>
          'attendance_approval_snapshot_id'
      ), period_start
    ),
    'pantry', atlas_core.issue_223_source_date_fingerprint(
      'PANTRY', atlas_core.pa_05b_safe_uuid(
        v_sources -> 'pantry' -> 'selected' ->>
          'pantry_need_approval_snapshot_id'
      ), period_start
    )
  );

  v_currentness := case
    when v_current is null or v_current = 'null'::jsonb then 'NOT_GENERATED'
    when v_sources -> 'weekly_menu' ->> 'selection_state' = 'SELECTED'
      and v_sources -> 'attendance' ->> 'selection_state' = 'SELECTED'
      and v_sources -> 'pantry' ->> 'selection_state' = 'SELECTED'
      and v_current ->> 'weekly_menu_id' =
        v_sources -> 'weekly_menu' -> 'selected' ->> 'weekly_menu_id'
      and v_current ->> 'attendance_batch_id' =
        v_sources -> 'attendance' -> 'selected' ->> 'attendance_batch_id'
      and v_current ->> 'pantry_need_batch_id' =
        v_sources -> 'pantry' -> 'selected' ->> 'pantry_need_batch_id'
      and v_current_fingerprints = v_selected_fingerprints
      then 'CURRENT'
    else 'OUTDATED'
  end;

  v_payload := pg_catalog.jsonb_set(
    pg_catalog.jsonb_set(
      v_payload, '{downstream_currentness}',
      pg_catalog.to_jsonb(v_currentness), true
    ),
    '{source_date_fingerprints}',
    pg_catalog.jsonb_build_object(
      'service_date', period_start,
      'current', v_current_fingerprints,
      'selected', v_selected_fingerprints
    ), true
  );

  return v_payload;
end;
$$;

revoke execute on function
  atlas_core.planning_contract_01_preflight_payload(date, date, jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.planning_contract_01_preflight_payload(date, date, jsonb)
to atlas_read_runtime, atlas_planning_command_runtime,
  atlas_need_generation_runtime;

reset role;

set role atlas_need_generation_runtime;

create or replace function atlas_api.execute_need_generation(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_contract text := request ->> 'contract_version';
  v_service_date date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'service_date'
  );
  v_period_start date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'period_start'
  );
  v_period_end date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'period_end'
  );
  v_v2_request jsonb;
  v_result jsonb;
  v_legacy_overlap jsonb;
  v_prior_compatibility text := pg_catalog.current_setting(
    'atlas.issue_223_period_compatibility', true
  );
begin
  if v_contract = 'RMVP-04.v2' then
    if v_period_start is not null
       and v_period_end is not null
       and v_period_start is distinct from v_period_end then
      return atlas_core.planning_contract_01_command_error(
        request, 'execute_need_generation', 'RMVP-04.v2',
        'MULTI_DAY_NEED_GENERATION_RETIRED',
        'Public multi-day Need Generation is retired; use one service date.'
      );
    end if;
    perform pg_catalog.set_config(
      'atlas.issue_223_period_compatibility', 'true', true
    );
    v_result := atlas_core.issue_223_execute_need_generation_v2(request);
    perform pg_catalog.set_config(
      'atlas.issue_223_period_compatibility',
      coalesce(v_prior_compatibility, ''), true
    );
    return v_result;
  end if;

  if v_contract is distinct from 'RMVP-04.v3'
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object'
     or v_service_date is null
     or (request -> 'payload') - array[
       'service_date', 'expected_current_need_generation_run_id'
     ] <> '{}'::jsonb
     or not (request -> 'payload' ?& array[
       'service_date', 'expected_current_need_generation_run_id'
     ]) then
    return atlas_core.planning_contract_01_command_error(
      request, 'execute_need_generation', 'RMVP-04.v3',
      'VALIDATION_FAILED',
      'The daily Need Generation payload is invalid.'
    );
  end if;

  v_v2_request := pg_catalog.jsonb_set(
    pg_catalog.jsonb_set(
      request, '{contract_version}', '"RMVP-04.v2"'::jsonb, true
    ),
    '{payload}',
    pg_catalog.jsonb_build_object(
      'period_start', v_service_date,
      'period_end', v_service_date,
      'expected_current_need_generation_run_id',
        request -> 'payload' -> 'expected_current_need_generation_run_id'
    ), true
  );
  v_result := atlas_core.issue_223_execute_need_generation_v2(v_v2_request);

  if v_result ->> 'error_code' = 'PLANNING_INPUTS_NOT_READY'
     and exists (
       select 1
       from pg_catalog.jsonb_array_elements(
         coalesce(
           v_result -> 'blocking_references', '[]'::jsonb
         )
       ) issue
       where issue ->> 'issue_code' =
         'ACTIVE_LEGACY_NEED_RANGE_OVERLAP'
     ) then
    select issue -> 'legacy_overlap'
    into v_legacy_overlap
    from pg_catalog.jsonb_array_elements(
      coalesce(
        v_result -> 'blocking_references', '[]'::jsonb
      )
    ) issue
    where issue ->> 'issue_code' = 'ACTIVE_LEGACY_NEED_RANGE_OVERLAP'
    limit 1;
    v_result := pg_catalog.jsonb_set(
      pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          v_result, '{error_code}',
          '"ACTIVE_LEGACY_NEED_RANGE_OVERLAP"'::jsonb, true
        ),
        '{safe_operator_message}',
        '"An active historical multi-day Need commitment contains this service date."'::jsonb,
        true
      ),
      '{legacy_overlap}', v_legacy_overlap, true
    );
  end if;

  return pg_catalog.jsonb_set(
    v_result, '{contract_version}', '"RMVP-04.v3"'::jsonb, true
  );
end;
$$;

revoke execute on function atlas_api.execute_need_generation(jsonb)
from public, anon, authenticated, service_role;
grant execute on function atlas_api.execute_need_generation(jsonb)
to authenticated;
comment on function atlas_api.execute_need_generation(jsonb) is
  'RMVP-04.v2 exact-day compatibility and RMVP-04.v3 daily atomic Need Generation dispatcher; active historical multi-day overlap blocks new daily authority.';

reset role;

set role atlas_owner;
revoke create on schema atlas_api from atlas_need_generation_runtime;
revoke create on schema atlas_core from atlas_read_runtime;
reset role;

revoke atlas_read_runtime, atlas_need_generation_runtime from postgres;
