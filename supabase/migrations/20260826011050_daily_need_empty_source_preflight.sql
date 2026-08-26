-- Block initial daily Need execution when the selected immutable source
-- snapshots contain neither Menu demand nor positive Pantry-direct demand for
-- the service date. Historical RMVP-03B evaluations/issues and H0C
-- EMPTY_ACTIVE_RELEASE remain unchanged.

grant atlas_read_runtime to postgres with set true;

set role atlas_owner;
grant create on schema atlas_core to atlas_read_runtime;
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
  v_has_menu_source boolean := false;
  v_has_pantry_source boolean := false;
  v_no_source_issue jsonb;
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
     ) is distinct from 'true' then
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
  end if;

  -- This is an automatic execution-preflight rule only. It deliberately runs
  -- after the existing source selection/compatibility projection and never
  -- writes an RMVP-03B evaluation or historical issue.
  if v_payload ->> 'readiness_state' = 'READY'
     and (v_current is null or v_current = 'null'::jsonb) then
    select exists (
      select 1
      from atlas_planning.weekly_menu_approval_snapshot_lines line
      join atlas_admin.dishes dish on dish.dish_id = line.dish_id
      where line.weekly_menu_approval_snapshot_id =
        atlas_core.pa_05b_safe_uuid(
          v_sources -> 'weekly_menu' -> 'selected' ->>
            'weekly_menu_approval_snapshot_id'
        )
        and line.service_date = period_start
        and (
          dish.dish_status <> 'ACTIVE'
          or dish.requires_need_generation
        )
    ) into v_has_menu_source;

    select exists (
      select 1
      from atlas_planning.pantry_need_approval_snapshot_lines line
      where line.pantry_need_approval_snapshot_id =
        atlas_core.pa_05b_safe_uuid(
          v_sources -> 'pantry' -> 'selected' ->>
            'pantry_need_approval_snapshot_id'
        )
        and line.service_date = period_start
        and line.requested_quantity > 0
    ) into v_has_pantry_source;

    if not v_has_menu_source and not v_has_pantry_source then
      v_no_source_issue := pg_catalog.jsonb_build_object(
        'severity', 'BLOCKING',
        'issue_code', 'NO_NEED_SOURCE_FOR_SERVICE_DATE',
        'message', 'Không có nhu cầu cần lập cho ngày này.',
        'input_type', 'NEED_GENERATION',
        'school_id', null,
        'service_date', period_start
      );
      v_payload := pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          pg_catalog.jsonb_set(
            v_payload, '{readiness_state}', '"BLOCKED"'::jsonb, true
          ),
          '{issues}',
          coalesce(v_payload -> 'issues', '[]'::jsonb)
            || pg_catalog.jsonb_build_array(v_no_source_issue),
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
    end if;
  end if;

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

set role atlas_owner;
revoke create on schema atlas_core from atlas_read_runtime;
reset role;

revoke atlas_read_runtime from postgres;
