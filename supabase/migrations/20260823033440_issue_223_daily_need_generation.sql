-- ISSUE-223: make the connected school-catering Need command daily.
--
-- Existing multi-day runs remain untouched and the RMVP-04.v2 implementation
-- remains callable through the same public function. RMVP-04.v3 accepts only a
-- service_date and executes the established transaction with D..D.

grant atlas_read_runtime, atlas_need_generation_runtime to postgres with set true;

set role atlas_owner;
grant create on schema atlas_core
to atlas_need_generation_runtime, atlas_read_runtime;
reset role;

-- Preserve the approved period implementation as compatibility code, then put
-- a version dispatcher back at the canonical public API name.
set role atlas_need_generation_runtime;
alter function atlas_api.execute_need_generation(jsonb)
  set schema atlas_core;
alter function atlas_core.execute_need_generation(jsonb)
  rename to issue_223_execute_need_generation_v2;
revoke execute on function atlas_core.issue_223_execute_need_generation_v2(jsonb)
  from public, anon, authenticated, service_role;
grant execute on function atlas_core.issue_223_execute_need_generation_v2(jsonb)
  to atlas_need_generation_runtime;
reset role;

-- Keep the former preflight as the compatibility implementation for periods.
set role atlas_read_runtime;
alter function atlas_core.planning_contract_01_preflight_payload(date, date, jsonb)
  rename to issue_223_period_preflight_payload;
revoke execute on function
  atlas_core.issue_223_period_preflight_payload(date, date, jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.issue_223_period_preflight_payload(date, date, jsonb)
to atlas_read_runtime, atlas_planning_command_runtime,
  atlas_need_generation_runtime;

-- A fingerprint is evidence for currentness only. The generated run continues
-- to bind the exact immutable parent approval snapshot and snapshot lines.
create or replace function atlas_core.issue_223_source_date_fingerprint(
  source_kind text,
  approval_snapshot_id uuid,
  service_date date
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_facts jsonb;
begin
  if source_kind = 'WEEKLY_MENU' then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'weekly_menu_line_id', line.weekly_menu_line_id,
          'school_id', line.school_id,
          'service_date', line.service_date,
          'menu_slot_code', line.menu_slot_code,
          'dish_id', line.dish_id,
          'source_row_reference', line.source_row_reference
        ) order by line.school_id, line.menu_slot_code, line.weekly_menu_line_id
      ), '[]'::jsonb
    ) into v_facts
    from atlas_planning.weekly_menu_approval_snapshot_lines line
    where line.weekly_menu_approval_snapshot_id = approval_snapshot_id
      and line.service_date = issue_223_source_date_fingerprint.service_date;
  elsif source_kind = 'ATTENDANCE' then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'attendance_line_id', line.attendance_line_id,
          'school_id', line.school_id,
          'service_date', line.service_date,
          'student_portions', line.student_portions,
          'teacher_portions', line.teacher_portions,
          'source_row_reference', line.source_row_reference
        ) order by line.school_id, line.attendance_line_id
      ), '[]'::jsonb
    ) into v_facts
    from atlas_planning.attendance_approval_snapshot_lines line
    where line.attendance_approval_snapshot_id = approval_snapshot_id
      and line.service_date = issue_223_source_date_fingerprint.service_date;
  elsif source_kind = 'PANTRY' then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'pantry_need_line_id', line.pantry_need_line_id,
          'service_date', line.service_date,
          'school_id', line.school_id,
          'delivery_location_id', line.delivery_location_id,
          'ingredient_id', line.ingredient_id,
          'unit_id', line.unit_id,
          'pantry_need_purpose_id', line.pantry_need_purpose_id,
          'requested_quantity', line.requested_quantity,
          'note', line.note,
          'source_request_reference', line.source_request_reference,
          'source_row_reference', line.source_row_reference
        ) order by line.school_id, line.delivery_location_id,
          line.ingredient_id, line.unit_id, line.pantry_need_line_id
      ), '[]'::jsonb
    ) into v_facts
    from atlas_planning.pantry_need_approval_snapshot_lines line
    where line.pantry_need_approval_snapshot_id = approval_snapshot_id
      and line.service_date = issue_223_source_date_fingerprint.service_date;
  else
    raise exception using errcode = '22023',
      message = 'Unsupported Planning source kind.';
  end if;

  return pg_catalog.md5(v_facts::text);
end;
$$;

revoke execute on function
  atlas_core.issue_223_source_date_fingerprint(text, uuid, date)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.issue_223_source_date_fingerprint(text, uuid, date)
to atlas_read_runtime, atlas_planning_command_runtime,
  atlas_need_generation_runtime;

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
begin
  if period_start is distinct from period_end
     or pg_catalog.current_setting(
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

  return pg_catalog.jsonb_set(
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
declare
  v_contract text := request ->> 'contract_version';
  v_service_date date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'service_date'
  );
  v_v2_request jsonb;
  v_result jsonb;
  v_prior_compatibility text := pg_catalog.current_setting(
    'atlas.issue_223_period_compatibility', true
  );
begin
  if v_contract = 'RMVP-04.v2' then
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
  'RMVP-04.v2 compatibility and RMVP-04.v3 daily atomic Need Generation dispatcher.';

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_need_generation_runtime;
revoke create on schema atlas_core from atlas_need_generation_runtime;
revoke create on schema atlas_core from atlas_read_runtime;
reset role;

revoke atlas_read_runtime, atlas_need_generation_runtime from postgres;
