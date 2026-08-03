-- RMVP-04: connected Need Generation.
--
-- One exact readiness decision becomes immutable Recipe-derived and Pantry-direct
-- theoretical demand, then follows the existing validate/release lifecycle. This
-- migration adds no relation, view, lifecycle state, trigger, source registry,
-- formula engine, downstream record, or production seed.

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_roles
    where rolname = 'atlas_need_generation_runtime'
  ) then
    create role atlas_need_generation_runtime nologin noinherit;
  end if;
end
$$;

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values (
  'planning.need_generation.write',
  'Create and control Need Generation',
  'PLANNING',
  'ACTIVE'
);

set role atlas_owner;

create function atlas_core.rmvp_04_safe_date(value text)
returns date
language plpgsql
immutable
set search_path = ''
as $$
begin
  if value is null or value !~ '^\d{4}-\d{2}-\d{2}$' then
    return null;
  end if;
  return value::date;
exception when others then
  return null;
end;
$$;

create function atlas_core.rmvp_04_error(
  request jsonb,
  operation_name text,
  error_code text,
  safe_message text,
  is_read boolean default false,
  retryable boolean default false,
  field_errors jsonb default '[]'::jsonb,
  blocking_references jsonb default '[]'::jsonb,
  actual_version bigint default null
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RMVP-04.v1',
      'error_code', error_code,
      'safe_message', safe_message,
      'domain', 'PLANNING',
      case when is_read then 'read_name' else 'command_name' end,
        operation_name,
      'retryable', retryable,
      'field_errors', coalesce(field_errors, '[]'::jsonb),
      'blocking_references', coalesce(blocking_references, '[]'::jsonb),
      'expected_version', request ->> 'expected_version',
      'actual_version', actual_version,
      'correlation_id', request ->> 'correlation_id',
      'command_id', case when is_read then null else request ->> 'command_id' end
    )
  );
$$;

create function atlas_core.rmvp_04_authorize_global(
  request jsonb,
  capability_code text,
  operation_name text,
  is_read boolean default false
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_context jsonb;
  v_actor_id uuid;
  v_error jsonb;
begin
  v_context := atlas_core.pa_05b_resolve_actor(
    request,
    'PLANNING',
    operation_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'error',
      (v_context -> 'error') || pg_catalog.jsonb_build_object(
        'contract_version', 'RMVP-04.v1',
        case when is_read then 'read_name' else 'command_name' end,
          operation_name
      )
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_error := atlas_core.pa_05b_authorize_actor(
    request,
    v_actor_id,
    capability_code,
    'PLANNING',
    operation_name,
    null,
    null,
    null
  );
  if v_error is not null then
    return pg_catalog.jsonb_build_object(
      'error',
      v_error || pg_catalog.jsonb_build_object(
        'contract_version', 'RMVP-04.v1',
        case when is_read then 'read_name' else 'command_name' end,
          operation_name
      )
    );
  end if;
  return pg_catalog.jsonb_build_object('actor_id', v_actor_id);
end;
$$;

create function atlas_core.rmvp_04_validate_read(request jsonb, read_name text)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_filters jsonb;
  v_detail jsonb;
  v_start date;
  v_end date;
  v_limit bigint;
  v_offset bigint;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_04_error(
      coalesce(request, '{}'::jsonb), read_name, 'VALIDATION_FAILED',
      'The read request must be a JSON object.', true
    );
  end if;
  if request - array[
    'contract_version', 'requested_by_auth_subject', 'correlation_id', 'payload'
  ] <> '{}'::jsonb or not (request ?& array[
    'contract_version', 'requested_by_auth_subject', 'correlation_id', 'payload'
  ]) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'request',
        'message', 'Provide exactly the RMVP-04 read envelope.'
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-04.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version', 'message', 'Use RMVP-04.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject', 'message', 'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'correlation_id', 'message', 'A valid UUID is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_typeof(request -> 'payload') is distinct from 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload', 'message', 'A JSON object is required.'
      )
    );
  else
    v_payload := request -> 'payload';
    if v_payload - array[
      'period_start', 'period_end', 'need_generation_run_id', 'filters',
      'group_offset', 'group_limit', 'detail_group'
    ] <> '{}'::jsonb or not (v_payload ?& array['period_start', 'period_end']) then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload', 'message', 'The workbench payload contains invalid fields.'
        )
      );
    end if;
    v_start := atlas_core.rmvp_04_safe_date(v_payload ->> 'period_start');
    v_end := atlas_core.rmvp_04_safe_date(v_payload ->> 'period_end');
    if v_start is null or v_end is null or v_end < v_start then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.period', 'message', 'A valid inclusive period is required.'
        )
      );
    end if;
    if v_payload ? 'need_generation_run_id'
      and v_payload -> 'need_generation_run_id' <> 'null'::jsonb
      and atlas_core.pa_05b_safe_uuid(
        v_payload ->> 'need_generation_run_id'
      ) is null
    then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.need_generation_run_id', 'message', 'Use null or one valid UUID.'
        )
      );
    end if;
    v_offset := coalesce(
      atlas_core.pa_05b_safe_bigint(v_payload ->> 'group_offset'), 0
    );
    v_limit := coalesce(
      atlas_core.pa_05b_safe_bigint(v_payload ->> 'group_limit'), 100
    );
    if v_offset < 0 then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.group_offset', 'message', 'Offset must be zero or greater.'
        )
      );
    end if;
    if v_limit < 1 or v_limit > 250 then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.group_limit', 'message', 'Limit must be between 1 and 250.'
        )
      );
    end if;
    if v_payload ? 'filters' and v_payload -> 'filters' <> 'null'::jsonb then
      if pg_catalog.jsonb_typeof(v_payload -> 'filters') <> 'object' then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'payload.filters', 'message', 'Filters must be an object.'
          )
        );
      else
        v_filters := v_payload -> 'filters';
        if v_filters - array[
          'service_date', 'school_id', 'ingredient_id', 'contribution_family'
        ] <> '{}'::jsonb
          or (v_filters ? 'service_date'
            and v_filters -> 'service_date' <> 'null'::jsonb
            and atlas_core.rmvp_04_safe_date(v_filters ->> 'service_date') is null)
          or (v_filters ? 'school_id'
            and v_filters -> 'school_id' <> 'null'::jsonb
            and atlas_core.pa_05b_safe_uuid(v_filters ->> 'school_id') is null)
          or (v_filters ? 'ingredient_id'
            and v_filters -> 'ingredient_id' <> 'null'::jsonb
            and atlas_core.pa_05b_safe_uuid(v_filters ->> 'ingredient_id') is null)
          or (v_filters ? 'contribution_family'
            and v_filters -> 'contribution_family' <> 'null'::jsonb
            and v_filters ->> 'contribution_family' not in (
              'RECIPE_DERIVED', 'PANTRY_DIRECT'
            ))
        then
          v_errors := v_errors || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'field', 'payload.filters', 'message', 'One or more filters are invalid.'
            )
          );
        end if;
      end if;
    end if;
    if v_payload ? 'detail_group' and v_payload -> 'detail_group' <> 'null'::jsonb then
      if pg_catalog.jsonb_typeof(v_payload -> 'detail_group') <> 'object' then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'payload.detail_group', 'message', 'Detail group must be an object.'
          )
        );
      else
        v_detail := v_payload -> 'detail_group';
        if v_detail - array[
          'service_date', 'school_id', 'delivery_location_id', 'ingredient_id', 'unit_id'
        ] <> '{}'::jsonb or not (v_detail ?& array[
          'service_date', 'school_id', 'delivery_location_id', 'ingredient_id', 'unit_id'
        ]) or atlas_core.rmvp_04_safe_date(v_detail ->> 'service_date') is null
          or atlas_core.pa_05b_safe_uuid(v_detail ->> 'school_id') is null
          or atlas_core.pa_05b_safe_uuid(v_detail ->> 'delivery_location_id') is null
          or atlas_core.pa_05b_safe_uuid(v_detail ->> 'ingredient_id') is null
          or atlas_core.pa_05b_safe_uuid(v_detail ->> 'unit_id') is null
        then
          v_errors := v_errors || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'field', 'payload.detail_group', 'message', 'The complete group identity is required.'
            )
          );
        end if;
      end if;
    end if;
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_04_error(
      request, read_name, 'VALIDATION_FAILED',
      'The Need Generation read request is invalid.', true, false, v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_core.rmvp_04_validate_command(
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
  v_payload jsonb;
  v_reason text := request ->> 'reason_code';
  v_note text := nullif(pg_catalog.btrim(request ->> 'reason_note'), '');
  v_requested_at timestamptz;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_04_error(
      coalesce(request, '{}'::jsonb), command_name, 'VALIDATION_FAILED',
      'The command request must be a JSON object.'
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
        'field', 'request', 'message', 'The complete Atlas command envelope is required.'
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-04.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version', 'message', 'Use RMVP-04.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
    or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
    or atlas_core.pa_05b_safe_uuid(
      request ->> 'requested_by_auth_subject'
    ) is null
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'identity', 'message', 'Valid command, correlation, and subject UUIDs are required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
    or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') < 1
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_version', 'message', 'A positive integer version is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
    or pg_catalog.length(request ->> 'idempotency_key') > 200
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'idempotency_key', 'message', 'A nonblank key of at most 200 characters is required.'
      )
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(
    request ->> 'requested_at'
  );
  if v_requested_at is null
    or v_requested_at > pg_catalog.transaction_timestamp()
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_at', 'message', 'A valid non-future timestamp is required.'
      )
    );
  end if;
  if not (request ? 'reason_note')
    or (request -> 'reason_note' <> 'null'::jsonb
      and pg_catalog.jsonb_typeof(request -> 'reason_note') <> 'string')
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason_note', 'message', 'Reason note must be null or text.'
      )
    );
  end if;
  if pg_catalog.jsonb_typeof(request -> 'payload') is distinct from 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload', 'message', 'A JSON object is required.'
      )
    );
  else
    v_payload := request -> 'payload';
    if command_name = 'create_need_generation_run' then
      if v_reason is distinct from 'NEED_GENERATION_CREATED'
        or request -> 'reason_note' <> 'null'::jsonb
      then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'reason_code', 'message', 'Use NEED_GENERATION_CREATED with a null note.'
          )
        );
      end if;
      if v_payload - array[
        'planning_input_set_id', 'planning_input_evaluation_id',
        'period_start', 'period_end'
      ] <> '{}'::jsonb or not (v_payload ?& array[
        'planning_input_set_id', 'planning_input_evaluation_id',
        'period_start', 'period_end'
      ]) or atlas_core.pa_05b_safe_uuid(
        v_payload ->> 'planning_input_set_id'
      ) is null or atlas_core.pa_05b_safe_uuid(
        v_payload ->> 'planning_input_evaluation_id'
      ) is null or atlas_core.rmvp_04_safe_date(
        v_payload ->> 'period_start'
      ) is null or atlas_core.rmvp_04_safe_date(
        v_payload ->> 'period_end'
      ) is null or atlas_core.rmvp_04_safe_date(
        v_payload ->> 'period_end'
      ) < atlas_core.rmvp_04_safe_date(v_payload ->> 'period_start')
      then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'payload', 'message', 'Provide the exact input set, evaluation, and inclusive period.'
          )
        );
      end if;
    else
      if v_payload - array['need_generation_run_id'] <> '{}'::jsonb
        or not (v_payload ? 'need_generation_run_id')
        or atlas_core.pa_05b_safe_uuid(
          v_payload ->> 'need_generation_run_id'
        ) is null
      then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'payload.need_generation_run_id', 'message', 'One valid run UUID is required.'
          )
        );
      end if;
      if command_name = 'validate_need_generation_run'
        and (v_reason is distinct from 'NEED_GENERATION_VALIDATED'
          or request -> 'reason_note' <> 'null'::jsonb)
      then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'reason_code', 'message', 'Use NEED_GENERATION_VALIDATED with a null note.'
          )
        );
      elsif command_name = 'release_need_generation_run'
        and (v_reason is distinct from 'NEED_GENERATION_RELEASED'
          or request -> 'reason_note' <> 'null'::jsonb)
      then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'reason_code', 'message', 'Use NEED_GENERATION_RELEASED with a null note.'
          )
        );
      elsif command_name = 'invalidate_need_generation_run'
        and (v_reason not in ('UPSTREAM_SOURCE_CHANGED', 'PLANNING_CORRECTION')
          or v_note is null)
      then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'reason_code', 'message', 'Use an allowed correction reason and a nonblank note.'
          )
        );
      end if;
    end if;
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_04_error(
      request, command_name, 'VALIDATION_FAILED',
      'The Need Generation command request is invalid.', false, false, v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_core.rmvp_04_prepare_command(
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
  v_actor_id uuid;
  v_begin jsonb;
begin
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
    'status', 'READY',
    'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

create function atlas_core.rmvp_04_record_change(
  request jsonb,
  actor_id uuid,
  receipt_id uuid,
  event_type text,
  run_id uuid,
  version_before bigint,
  version_after bigint,
  before_summary jsonb,
  after_summary jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_event_id uuid;
  v_audit_id uuid;
begin
  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version, command_receipt_id, command_id, correlation_id,
    actor_id, occurred_at, payload_summary
  ) values (
    event_type, 'PLANNING', 'NeedGenerationRun', run_id,
    version_after, receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id, pg_catalog.transaction_timestamp(), after_summary
  ) returning domain_event_id into v_event_id;
  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version_before, aggregate_version_after,
    command_receipt_id, command_id, correlation_id, actor_id,
    reason_code, reason_note, before_summary, after_summary,
    source_interface, occurred_at
  ) values (
    event_type, 'PLANNING', 'NeedGenerationRun', run_id,
    version_before, version_after, receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id, request ->> 'reason_code',
    nullif(pg_catalog.btrim(request ->> 'reason_note'), ''),
    before_summary, after_summary, 'atlas_api',
    pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_id;
  return pg_catalog.jsonb_build_object(
    'domain_event_id', v_event_id,
    'audit_event_id', v_audit_id
  );
end;
$$;

-- CMD-15's merged Pantry membership guard treated an initial Recipe line as
-- matching every destination-specific revision because its completeness
-- fallback compared the revision location to itself. Match initial Recipe
-- membership to its immutable captured contribution location; corrected Recipe
-- lines still retain predecessor location and Pantry retains typed source location.
create or replace function atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid;
  v_source_kind text;
  v_current_snapshot_id uuid;
begin
  v_batch_id := new.confirmed_need_batch_id;

  select batch.source_kind, batch.current_need_generation_release_snapshot_id
  into strict v_source_kind, v_current_snapshot_id
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;

  if v_source_kind = 'WHOLESALE' then
    if exists (
      select 1
      from atlas_planning.confirmed_need_line_revision_contributions contribution
      where contribution.confirmed_need_batch_id = v_batch_id
    ) then
      raise exception using errcode = '23514', message = 'Wholesale Confirmed Need revisions cannot have contributions';
    end if;
    return null;
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = v_batch_id
      and revision.source_kind = 'NEED_GENERATION'
      and not exists (
        select 1
        from atlas_planning.confirmed_need_line_revision_contributions contribution
        where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
      )
  ) then
    raise exception using errcode = '23514', message = 'Every Need Generation revision requires nonempty contribution membership';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
    join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_line_id = revision.confirmed_need_line_id
    join atlas_planning.need_generation_release_snapshot_lines snapshot_line
      on snapshot_line.need_generation_release_snapshot_line_id = contribution.need_generation_release_snapshot_line_id
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = contribution.theoretical_need_line_id
    join atlas_admin.schools school
      on school.school_id = contribution.school_id
    left join lateral (
      select prior_contribution.delivery_location_id
      from atlas_planning.confirmed_need_line_revision_contributions prior_contribution
      where prior_contribution.confirmed_need_batch_id = v_batch_id
        and prior_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
      order by prior_contribution.created_at,
               prior_contribution.confirmed_need_line_revision_contribution_id
      limit 1
    ) predecessor_contribution
      on theoretical.contribution_family = 'RECIPE_DERIVED'
     and theoretical.predecessor_theoretical_need_line_id is not null
    where contribution.confirmed_need_batch_id = v_batch_id
      and (
        revision.source_kind <> 'NEED_GENERATION'
        or contribution.confirmed_need_batch_id <> revision.confirmed_need_batch_id
        or contribution.confirmed_need_line_id <> revision.confirmed_need_line_id
        or contribution.need_generation_run_id <> revision.need_generation_run_id
        or contribution.need_generation_run_version <> revision.need_generation_run_version
        or contribution.need_generation_release_snapshot_id <> revision.need_generation_release_snapshot_id
        or snapshot_line.need_generation_release_snapshot_id <> revision.need_generation_release_snapshot_id
        or snapshot_line.need_generation_run_id <> revision.need_generation_run_id
        or snapshot_line.released_run_version <> revision.need_generation_run_version
        or snapshot_line.theoretical_need_line_id <> theoretical.theoretical_need_line_id
        or theoretical.need_generation_run_id <> revision.need_generation_run_id
        or theoretical.line_disposition <> 'ACTIVE'
        or theoretical.service_date <> line.service_date
        or theoretical.school_id <> line.school_id
        or theoretical.ingredient_id <> line.ingredient_id
        or theoretical.unit_id <> line.controlled_unit_id
        or theoretical.theoretical_quantity <> contribution.source_theoretical_quantity
        or contribution.service_date <> line.service_date
        or contribution.customer_id <> line.customer_id
        or contribution.school_id <> line.school_id
        or contribution.delivery_location_id <> line.delivery_location_id
        or contribution.ingredient_id <> line.ingredient_id
        or contribution.source_unit_id <> line.controlled_unit_id
        or contribution.controlled_unit_id <> line.controlled_unit_id
        or contribution.controlled_contribution_quantity <> contribution.source_theoretical_quantity
        or school.customer_id <> line.customer_id
        or contribution.delivery_location_id is distinct from case
          when theoretical.contribution_family = 'PANTRY_DIRECT'
            then theoretical.delivery_location_id
          when theoretical.predecessor_theoretical_need_line_id is not null
            then predecessor_contribution.delivery_location_id
          else revision.delivery_location_id
        end
      )
  ) then
    raise exception using errcode = '23514', message = 'Need Generation contribution facts are not exact active release facts';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = v_batch_id
      and revision.source_kind = 'NEED_GENERATION'
      and (
        revision.theoretical_quantity is distinct from (
          select sum(contribution.controlled_contribution_quantity)
          from atlas_planning.confirmed_need_line_revision_contributions contribution
          where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
        )
        or exists (
          select 1
          from atlas_planning.need_generation_release_snapshot_lines snapshot_line
          join atlas_planning.theoretical_need_lines theoretical
            on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
          where snapshot_line.need_generation_release_snapshot_id = revision.need_generation_release_snapshot_id
            and theoretical.line_disposition = 'ACTIVE'
            and theoretical.contribution_family = 'RECIPE_DERIVED'
            and theoretical.predecessor_theoretical_need_line_id is not null
            and theoretical.service_date = revision.service_date
            and theoretical.school_id = revision.school_id
            and theoretical.ingredient_id = revision.ingredient_id
            and theoretical.unit_id = revision.unit_id
            and not exists (
              select 1
              from atlas_planning.confirmed_need_line_revision_contributions predecessor_contribution
              where predecessor_contribution.confirmed_need_batch_id = v_batch_id
                and predecessor_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
            )
        )
        or exists (
          select 1
          from atlas_planning.need_generation_release_snapshot_lines snapshot_line
          join atlas_planning.theoretical_need_lines theoretical
            on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
          left join lateral (
            select prior_contribution.delivery_location_id
            from atlas_planning.confirmed_need_line_revision_contributions prior_contribution
            where prior_contribution.confirmed_need_batch_id = v_batch_id
              and prior_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
            order by prior_contribution.created_at,
                     prior_contribution.confirmed_need_line_revision_contribution_id
            limit 1
          ) predecessor_contribution
            on theoretical.contribution_family = 'RECIPE_DERIVED'
           and theoretical.predecessor_theoretical_need_line_id is not null
          left join lateral (
            select captured.delivery_location_id
            from atlas_planning.confirmed_need_line_revision_contributions captured
            where captured.confirmed_need_batch_id = v_batch_id
              and captured.theoretical_need_line_id = theoretical.theoretical_need_line_id
            order by captured.created_at,
                     captured.confirmed_need_line_revision_contribution_id
            limit 1
          ) captured_contribution
            on theoretical.contribution_family = 'RECIPE_DERIVED'
           and theoretical.predecessor_theoretical_need_line_id is null
          where snapshot_line.need_generation_release_snapshot_id = revision.need_generation_release_snapshot_id
            and theoretical.line_disposition = 'ACTIVE'
            and theoretical.service_date = revision.service_date
            and theoretical.school_id = revision.school_id
            and theoretical.ingredient_id = revision.ingredient_id
            and theoretical.unit_id = revision.unit_id
            and revision.delivery_location_id is not distinct from case
              when theoretical.contribution_family = 'PANTRY_DIRECT'
                then theoretical.delivery_location_id
              when theoretical.predecessor_theoretical_need_line_id is not null
                then predecessor_contribution.delivery_location_id
              else captured_contribution.delivery_location_id
            end
            and not exists (
              select 1
              from atlas_planning.confirmed_need_line_revision_contributions contribution
              where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
                and contribution.theoretical_need_line_id = theoretical.theoretical_need_line_id
            )
        )
      )
  ) then
    raise exception using errcode = '23514', message = 'Need Generation revision membership is incomplete or its total is inexact';
  end if;

  if exists (
    select snapshot_line.theoretical_need_line_id
    from atlas_planning.need_generation_release_snapshot_lines snapshot_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
    left join atlas_planning.confirmed_need_line_revision_contributions contribution
      on contribution.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
    left join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
      and revision.confirmed_need_batch_id = v_batch_id
      and revision.is_current
    where snapshot_line.need_generation_release_snapshot_id = v_current_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    group by snapshot_line.theoretical_need_line_id
    having count(revision.confirmed_need_line_revision_id) <> 1
  ) then
    raise exception using errcode = '23514', message = 'Current Need Generation revisions must exactly partition the active release';
  end if;

  return null;
end;
$$;

create function atlas_core.rmvp_04_workbench_payload(
  period_start date,
  period_end date,
  requested_run_id uuid default null,
  filters jsonb default '{}'::jsonb,
  group_offset integer default 0,
  group_limit integer default 100,
  detail_group jsonb default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_set atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_terminal atlas_planning.need_generation_runs%rowtype;
  v_selected atlas_planning.need_generation_runs%rowtype;
  v_confirmed atlas_planning.confirmed_need_batches%rowtype;
  v_groups jsonb := '[]'::jsonb;
  v_group_count bigint := 0;
  v_detail jsonb := '[]'::jsonb;
  v_history jsonb := '[]'::jsonb;
  v_blockers jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_sources jsonb := '{}'::jsonb;
  v_materialization_mode text := 'NONE';
  v_can_materialize boolean := false;
  v_can_invalidate boolean := false;
  v_downstream_safe boolean := true;
  v_filter_date date := atlas_core.rmvp_04_safe_date(
    filters ->> 'service_date'
  );
  v_filter_school uuid := atlas_core.pa_05b_safe_uuid(
    filters ->> 'school_id'
  );
  v_filter_ingredient uuid := atlas_core.pa_05b_safe_uuid(
    filters ->> 'ingredient_id'
  );
  v_filter_family text := nullif(filters ->> 'contribution_family', '');
begin
  select input_set.* into v_set
  from atlas_planning.planning_input_sets as input_set
  where input_set.period_start = rmvp_04_workbench_payload.period_start
    and input_set.period_end = rmvp_04_workbench_payload.period_end;

  if v_set.planning_input_set_id is not null then
    select evaluation.* into v_evaluation
    from atlas_planning.planning_input_evaluations as evaluation
    where evaluation.planning_input_evaluation_id = v_set.current_evaluation_id;

    select run.* into v_terminal
    from atlas_planning.need_generation_runs as run
    where run.planning_input_set_id = v_set.planning_input_set_id
    order by run.attempt_ordinal desc
    limit 1;

    if requested_run_id is null then
      v_selected := v_terminal;
    else
      select run.* into v_selected
      from atlas_planning.need_generation_runs as run
      where run.need_generation_run_id = requested_run_id
        and run.planning_input_set_id = v_set.planning_input_set_id
        and run.period_start = rmvp_04_workbench_payload.period_start
        and run.period_end = rmvp_04_workbench_payload.period_end;
      if v_selected.need_generation_run_id is null then
        return pg_catalog.jsonb_build_object(
          'validation_error', 'FOREIGN_PERIOD_RUN'
        );
      end if;
    end if;

    v_sources := pg_catalog.jsonb_build_object(
      'weekly_menu', pg_catalog.jsonb_strip_nulls(
        pg_catalog.jsonb_build_object(
          'weekly_menu_id', v_evaluation.weekly_menu_id,
          'version', v_evaluation.weekly_menu_version,
          'approval_snapshot_id', v_evaluation.weekly_menu_approval_snapshot_id,
          'line_count', (
            select count(*)
            from atlas_planning.weekly_menu_approval_snapshot_lines as line
            where line.weekly_menu_approval_snapshot_id =
              v_evaluation.weekly_menu_approval_snapshot_id
          )
        )
      ),
      'attendance', pg_catalog.jsonb_strip_nulls(
        pg_catalog.jsonb_build_object(
          'attendance_batch_id', v_evaluation.attendance_batch_id,
          'version', v_evaluation.attendance_version,
          'approval_snapshot_id', v_evaluation.attendance_approval_snapshot_id,
          'line_count', (
            select count(*)
            from atlas_planning.attendance_approval_snapshot_lines as line
            where line.attendance_approval_snapshot_id =
              v_evaluation.attendance_approval_snapshot_id
          )
        )
      ),
      'pantry', pg_catalog.jsonb_strip_nulls(
        pg_catalog.jsonb_build_object(
          'pantry_need_batch_id', v_evaluation.pantry_need_batch_id,
          'version', v_evaluation.pantry_need_batch_version,
          'approval_snapshot_id', v_evaluation.pantry_need_approval_snapshot_id,
          'line_count', (
            select count(*)
            from atlas_planning.pantry_need_approval_snapshot_lines as line
            where line.pantry_need_approval_snapshot_id =
              v_evaluation.pantry_need_approval_snapshot_id
          )
        )
      )
    );

    select coalesce(pg_catalog.jsonb_agg(item order by ordinal desc), '[]'::jsonb)
    into v_history
    from (
      select run.attempt_ordinal as ordinal,
        pg_catalog.jsonb_build_object(
          'need_generation_run_id', run.need_generation_run_id,
          'attempt_ordinal', run.attempt_ordinal,
          'predecessor_need_generation_run_id',
            run.predecessor_need_generation_run_id,
          'status', run.run_status,
          'version', run.version,
          'generated_line_count', run.generated_line_count,
          'blocking_issue_count', run.blocking_issue_count,
          'warning_count', run.warning_count,
          'generated_at', run.generated_at,
          'validated_at', run.validated_at,
          'released_at', run.released_at,
          'invalidated_at', run.invalidated_at
        ) as item
      from atlas_planning.need_generation_runs as run
      where run.planning_input_set_id = v_set.planning_input_set_id
    ) as history;
  end if;

  if v_selected.need_generation_run_id is not null then
    select coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'need_generation_issue_id', issue.need_generation_issue_id,
        'issue_code', issue.issue_code,
        'message', issue.message,
        'school_id', issue.school_id,
        'service_date', issue.service_date,
        'ingredient_id', issue.ingredient_id,
        'unit_id', issue.unit_id,
        'theoretical_need_line_id', issue.theoretical_need_line_id
      ) order by issue.created_at, issue.need_generation_issue_id
    ), '[]'::jsonb)
    into v_blockers
    from atlas_planning.need_generation_issues as issue
    where issue.need_generation_run_id = v_selected.need_generation_run_id
      and issue.severity = 'BLOCKING';

    select coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'need_generation_issue_id', issue.need_generation_issue_id,
        'issue_code', issue.issue_code,
        'message', issue.message,
        'school_id', issue.school_id,
        'service_date', issue.service_date,
        'ingredient_id', issue.ingredient_id,
        'unit_id', issue.unit_id,
        'theoretical_need_line_id', issue.theoretical_need_line_id
      ) order by issue.created_at, issue.need_generation_issue_id
    ), '[]'::jsonb)
    into v_warnings
    from atlas_planning.need_generation_issues as issue
    where issue.need_generation_run_id = v_selected.need_generation_run_id
      and issue.severity = 'WARNING';

    with operational_lines as (
      select line.*,
        school.customer_id,
        school.school_name,
        coalesce(
          confirmed_revision.delivery_location_id,
          line.delivery_location_id,
          school.default_delivery_location_id
        ) as effective_delivery_location_id
      from atlas_planning.theoretical_need_lines as line
      join atlas_admin.schools as school on school.school_id = line.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions as contribution
        on contribution.theoretical_need_line_id = line.theoretical_need_line_id
       and contribution.need_generation_run_id = line.need_generation_run_id
      left join atlas_planning.confirmed_need_line_revisions as confirmed_revision
        on confirmed_revision.confirmed_need_line_revision_id =
          contribution.confirmed_need_line_revision_id
      where line.need_generation_run_id = v_selected.need_generation_run_id
        and (v_filter_date is null or line.service_date = v_filter_date)
        and (v_filter_school is null or line.school_id = v_filter_school)
        and (v_filter_ingredient is null or line.ingredient_id = v_filter_ingredient)
        and (v_filter_family is null or line.contribution_family = v_filter_family)
    ), grouped as (
      select line.service_date,
        line.customer_id,
        line.school_id,
        line.school_name,
        line.effective_delivery_location_id as delivery_location_id,
        location.location_name as delivery_location_name,
        line.ingredient_id,
        ingredient.ingredient_name,
        line.unit_id,
        unit.unit_name,
        sum(line.theoretical_quantity) as total_theoretical_quantity,
        sum(line.theoretical_quantity) filter (
          where line.contribution_family = 'RECIPE_DERIVED'
        ) as recipe_derived_quantity,
        sum(line.theoretical_quantity) filter (
          where line.contribution_family = 'PANTRY_DIRECT'
        ) as pantry_direct_quantity,
        count(*) filter (where line.line_disposition = 'ACTIVE') as active_count,
        count(*) filter (where line.line_disposition = 'REMOVED') as removed_count,
        (
          select count(*)
          from atlas_planning.need_generation_issues as issue
          where issue.need_generation_run_id = v_selected.need_generation_run_id
            and issue.severity = 'WARNING'
            and exists (
              select 1
              from operational_lines as issue_line
              where issue_line.theoretical_need_line_id =
                  issue.theoretical_need_line_id
                and issue_line.service_date = line.service_date
                and issue_line.customer_id = line.customer_id
                and issue_line.school_id = line.school_id
                and issue_line.effective_delivery_location_id =
                  line.effective_delivery_location_id
                and issue_line.ingredient_id = line.ingredient_id
                and issue_line.unit_id = line.unit_id
            )
        ) as warning_count
      from operational_lines as line
      join atlas_admin.delivery_locations as location
        on location.delivery_location_id = line.effective_delivery_location_id
      join atlas_admin.ingredients as ingredient
        on ingredient.ingredient_id = line.ingredient_id
      join atlas_admin.units as unit on unit.unit_id = line.unit_id
      group by line.service_date, line.customer_id, line.school_id,
        line.school_name, line.effective_delivery_location_id,
        location.location_name, line.ingredient_id, ingredient.ingredient_name,
        line.unit_id, unit.unit_name
    ), numbered as (
      select grouped.*, count(*) over () as total_count
      from grouped
    )
    select coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'service_date', page.service_date,
        'customer_id', page.customer_id,
        'school_id', page.school_id,
        'school_name', page.school_name,
        'delivery_location_id', page.delivery_location_id,
        'delivery_location_name', page.delivery_location_name,
        'ingredient_id', page.ingredient_id,
        'ingredient_name', page.ingredient_name,
        'unit_id', page.unit_id,
        'unit_name', page.unit_name,
        'total_theoretical_quantity', page.total_theoretical_quantity,
        'recipe_derived_quantity', coalesce(page.recipe_derived_quantity, 0),
        'pantry_direct_quantity', coalesce(page.pantry_direct_quantity, 0),
        'active_contribution_count', page.active_count,
        'removed_contribution_count', page.removed_count,
        'warning_count', page.warning_count
      ) order by page.service_date, page.school_name,
        page.delivery_location_name, page.ingredient_name, page.unit_name
    ), '[]'::jsonb), coalesce(max(page.total_count), 0)
    into v_groups, v_group_count
    from (
      select * from numbered
      order by service_date, school_name, delivery_location_name,
        ingredient_name, unit_name
      offset group_offset limit group_limit
    ) as page;

    if detail_group is not null then
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.jsonb_strip_nulls(pg_catalog.jsonb_build_object(
          'theoretical_need_line_id', line.theoretical_need_line_id,
          'contribution_family', line.contribution_family,
          'theoretical_quantity', line.theoretical_quantity,
          'unit_id', line.unit_id,
          'unit_name', unit.unit_name,
          'disposition', line.line_disposition,
          'dish_name', dish.dish_name,
          'recipe_id', line.recipe_id,
          'pantry_purpose', pantry.purpose_name_snapshot,
          'pantry_source_reference', pantry.source_request_reference,
          'warning_references', (
            select coalesce(pg_catalog.jsonb_agg(
              pg_catalog.jsonb_build_object(
                'issue_code', issue.issue_code,
                'message', issue.message
              ) order by issue.created_at
            ), '[]'::jsonb)
            from atlas_planning.need_generation_issues as issue
            where issue.need_generation_run_id = line.need_generation_run_id
              and issue.theoretical_need_line_id = line.theoretical_need_line_id
              and issue.severity = 'WARNING'
          )
        )) order by line.contribution_family, line.theoretical_need_line_id
      ), '[]'::jsonb)
      into v_detail
      from atlas_planning.theoretical_need_lines as line
      join atlas_admin.schools as school on school.school_id = line.school_id
      join atlas_admin.units as unit on unit.unit_id = line.unit_id
      left join atlas_admin.dishes as dish on dish.dish_id = line.dish_id
      left join atlas_planning.pantry_need_approval_snapshot_lines as pantry
        on pantry.pantry_need_approval_snapshot_id =
          line.pantry_need_approval_snapshot_id
       and pantry.pantry_need_line_id = line.pantry_need_line_id
      left join atlas_planning.confirmed_need_line_revision_contributions as contribution
        on contribution.theoretical_need_line_id = line.theoretical_need_line_id
       and contribution.need_generation_run_id = line.need_generation_run_id
      left join atlas_planning.confirmed_need_line_revisions as confirmed_revision
        on confirmed_revision.confirmed_need_line_revision_id =
          contribution.confirmed_need_line_revision_id
      where line.need_generation_run_id = v_selected.need_generation_run_id
        and line.service_date = atlas_core.rmvp_04_safe_date(
          detail_group ->> 'service_date'
        )
        and line.school_id = atlas_core.pa_05b_safe_uuid(
          detail_group ->> 'school_id'
        )
        and coalesce(
          confirmed_revision.delivery_location_id,
          line.delivery_location_id,
          school.default_delivery_location_id
        ) = atlas_core.pa_05b_safe_uuid(
          detail_group ->> 'delivery_location_id'
        )
        and line.ingredient_id = atlas_core.pa_05b_safe_uuid(
          detail_group ->> 'ingredient_id'
        )
        and line.unit_id = atlas_core.pa_05b_safe_uuid(
          detail_group ->> 'unit_id'
        );
    end if;

    select batch.* into v_confirmed
    from atlas_planning.confirmed_need_batches as batch
    where batch.source_kind = 'NEED_GENERATION'
      and (
        batch.current_need_generation_run_id = v_selected.need_generation_run_id
        or batch.origin_need_generation_run_id in (
          select chain.need_generation_run_id
          from atlas_planning.need_generation_runs as chain
          where chain.planning_input_set_id = v_selected.planning_input_set_id
        )
      )
    order by (
      batch.current_need_generation_run_id = v_selected.need_generation_run_id
    ) desc, batch.updated_at desc
    limit 1;

    if v_confirmed.confirmed_need_batch_id is not null then
      v_materialization_mode := case
        when v_confirmed.origin_need_generation_run_id =
          v_confirmed.current_need_generation_run_id then 'INITIAL'
        else 'CORRECTION'
      end;
    end if;

    v_can_materialize := v_selected.need_generation_run_id =
        v_terminal.need_generation_run_id
      and v_selected.run_status = 'RELEASED_FOR_CONFIRMATION'
      and not exists (
        select 1
        from atlas_planning.theoretical_need_lines as line
        where line.need_generation_run_id = v_selected.need_generation_run_id
          and line.line_disposition = 'ACTIVE'
          and line.theoretical_quantity = 0
      )
      and (
        v_confirmed.confirmed_need_batch_id is null
        or (
          v_confirmed.current_need_generation_run_id <>
            v_selected.need_generation_run_id
          and v_confirmed.batch_status in ('DRAFT_REVIEW', 'REOPENED')
        )
      );

    if v_selected.run_status = 'RELEASED_FOR_CONFIRMATION'
      and v_confirmed.confirmed_need_batch_id is not null
    then
      v_downstream_safe := v_confirmed.batch_status in (
        'DRAFT_REVIEW', 'REOPENED'
      ) and not exists (
        select 1
        from atlas_planning.purchase_handoff_batches as handoff
        where handoff.confirmed_need_batch_id =
          v_confirmed.confirmed_need_batch_id
          and handoff.handoff_status not in ('INVALIDATED', 'REOPENED')
      );
    end if;
    v_can_invalidate := v_selected.need_generation_run_id =
      v_terminal.need_generation_run_id
      and v_selected.run_status in (
        'GENERATED', 'VALIDATED', 'RELEASED_FOR_CONFIRMATION'
      )
      and v_downstream_safe;
  end if;

  return pg_catalog.jsonb_build_object(
    'period', pg_catalog.jsonb_build_object(
      'period_start', period_start, 'period_end', period_end
    ),
    'planning_input_set', case when v_set.planning_input_set_id is null
      then null else pg_catalog.jsonb_build_object(
        'planning_input_set_id', v_set.planning_input_set_id,
        'readiness_status', v_set.readiness_status,
        'current_evaluation_id', v_set.current_evaluation_id
      ) end,
    'current_evaluation', case when v_evaluation.planning_input_evaluation_id is null
      then null else pg_catalog.jsonb_build_object(
        'planning_input_evaluation_id',
          v_evaluation.planning_input_evaluation_id,
        'evaluation_version', v_evaluation.evaluation_version,
        'evaluation_result', v_evaluation.evaluation_result,
        'blocking_issue_count', v_evaluation.blocking_issue_count,
        'warning_count', v_evaluation.warning_count,
        'evaluated_at', v_evaluation.evaluated_at
      ) end,
    'source_evidence', v_sources,
    'terminal_run_id', v_terminal.need_generation_run_id,
    'selected_run', case when v_selected.need_generation_run_id is null
      then null else pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_selected.need_generation_run_id,
        'attempt_ordinal', v_selected.attempt_ordinal,
        'predecessor_need_generation_run_id',
          v_selected.predecessor_need_generation_run_id,
        'status', v_selected.run_status,
        'version', v_selected.version,
        'generated_line_count', v_selected.generated_line_count,
        'blocking_issue_count', v_selected.blocking_issue_count,
        'warning_count', v_selected.warning_count,
        'generated_at', v_selected.generated_at,
        'validated_at', v_selected.validated_at,
        'released_at', v_selected.released_at,
        'invalidated_at', v_selected.invalidated_at,
        'release_snapshot_id', (
          select release.need_generation_release_snapshot_id
          from atlas_planning.need_generation_release_snapshots as release
          where release.need_generation_run_id = v_selected.need_generation_run_id
        )
      ) end,
    'blocking_issues', v_blockers,
    'warnings', v_warnings,
    'grouped_requirements', v_groups,
    'atomic_detail', v_detail,
    'run_history', v_history,
    'materialization', pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id', v_confirmed.confirmed_need_batch_id,
      'confirmed_need_batch_version', v_confirmed.version,
      'confirmed_need_status', v_confirmed.batch_status,
      'materialization_mode', v_materialization_mode
    ),
    'allowed_actions', pg_catalog.jsonb_build_object(
      'create', coalesce(v_set.readiness_status = 'NEED_GENERATION_REQUESTED'
        and v_evaluation.evaluation_result = 'READY'
        and v_evaluation.blocking_issue_count = 0
        and (v_terminal.need_generation_run_id is null
          or v_terminal.run_status = 'INVALIDATED'), false),
      'validate', coalesce(v_selected.need_generation_run_id =
          v_terminal.need_generation_run_id
        and v_selected.run_status = 'GENERATED'
        and v_selected.blocking_issue_count = 0, false),
      'release', coalesce(v_selected.need_generation_run_id =
          v_terminal.need_generation_run_id
        and v_selected.run_status = 'VALIDATED'
        and v_selected.blocking_issue_count = 0, false),
      'materialize', coalesce(v_selected.need_generation_run_id =
          v_terminal.need_generation_run_id and v_can_materialize, false),
      'invalidate', coalesce(v_can_invalidate, false)
    ),
    'disabled_reasons', pg_catalog.jsonb_build_object(
      'create', case
        when v_set.planning_input_set_id is null
          or v_set.readiness_status <> 'NEED_GENERATION_REQUESTED'
          then 'Return to Sẵn sàng đầu vào and request Need Generation first.'
        when v_evaluation.evaluation_result <> 'READY'
          or v_evaluation.blocking_issue_count > 0
          then 'Planning Input Readiness must be READY without blockers.'
        when v_terminal.run_status <> 'INVALIDATED' then
          'The terminal Need Generation run is still active.'
        else null end,
      'validate', case
        when v_selected.run_status <> 'GENERATED'
          then 'Only the terminal generated run can be validated.'
        when v_selected.blocking_issue_count > 0
          then 'Resolve blocking issues through corrected source evidence.'
        else null end,
      'release', case
        when v_selected.run_status <> 'VALIDATED'
          then 'Validate the terminal run before release.'
        when v_selected.blocking_issue_count > 0
          then 'A run with blockers cannot be released.'
        else null end,
      'materialize', case
        when v_selected.run_status <> 'RELEASED_FOR_CONFIRMATION'
          then 'Release Need Generation before creating Confirmed Need.'
        when exists (
          select 1
          from atlas_planning.theoretical_need_lines as line
          where line.need_generation_run_id = v_selected.need_generation_run_id
            and line.line_disposition = 'ACTIVE'
            and line.theoretical_quantity = 0
        ) then 'CMD-15 requires corrected source evidence before materializing an active zero-quantity contribution.'
        when v_confirmed.current_need_generation_run_id =
          v_selected.need_generation_run_id
          then 'This released run is already materialized.'
        when v_confirmed.confirmed_need_batch_id is not null
          and v_confirmed.batch_status not in ('DRAFT_REVIEW', 'REOPENED')
          then 'Confirmed Need requires a separate controlled correction.'
        else null end,
      'invalidate', case
        when not v_downstream_safe
          then 'Downstream commitment requires a separate controlled correction.'
        when v_selected.run_status = 'INVALIDATED'
          then 'This run is already invalidated.'
        else null end
    ),
    'pagination', pg_catalog.jsonb_build_object(
      'offset', group_offset,
      'limit', group_limit,
      'total_groups', v_group_count,
      'has_more', group_offset + group_limit < v_group_count
    )
  );
end;
$$;

create function atlas_core.rmvp_04_success(
  request jsonb,
  actor_id uuid,
  receipt_id uuid,
  event_type text,
  run_id uuid,
  version_before bigint,
  version_after bigint,
  safe_message text,
  before_summary jsonb,
  after_summary jsonb,
  release_snapshot_id uuid default null
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_events jsonb;
  v_run atlas_planning.need_generation_runs%rowtype;
  v_response jsonb;
begin
  v_events := atlas_core.rmvp_04_record_change(
    request, actor_id, receipt_id, event_type, run_id,
    version_before, version_after, before_summary, after_summary
  );
  select run.* into v_run
  from atlas_planning.need_generation_runs as run
  where run.need_generation_run_id = run_id;
  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-04.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'planning_input_set_id', v_run.planning_input_set_id,
      'need_generation_run_id', run_id,
      'need_generation_release_snapshot_id', release_snapshot_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'need_generation_run_version', version_after
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'audit_event_id'
    ),
    'safe_operator_message', safe_message,
    'authoritative_readback', atlas_core.rmvp_04_workbench_payload(
      v_run.period_start, v_run.period_end, run_id, '{}'::jsonb, 0, 100, null
    )
  );
  return atlas_core.pa_05b_finish_command(receipt_id, v_response, true);
end;
$$;

create function atlas_api.create_need_generation_run(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_need_generation_run';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_set_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'planning_input_set_id'
  );
  v_evaluation_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'planning_input_evaluation_id'
  );
  v_start date := atlas_core.rmvp_04_safe_date(
    v_payload ->> 'period_start'
  );
  v_end date := atlas_core.rmvp_04_safe_date(v_payload ->> 'period_end');
  v_set atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_terminal atlas_planning.need_generation_runs%rowtype;
  v_contract atlas_planning.need_generation_calculation_contracts%rowtype;
  v_run_id uuid := gen_random_uuid();
  v_snapshot_id uuid := gen_random_uuid();
  v_now timestamptz := pg_catalog.transaction_timestamp();
  v_attempt bigint;
  v_selections jsonb := '[]'::jsonb;
  v_uses jsonb := '[]'::jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_selection_id uuid;
  v_use_id uuid;
  v_line_id uuid;
  v_quantity numeric(20, 6);
  v_predecessor atlas_planning.theoretical_need_lines%rowtype;
  v_menu record;
  v_revision record;
  v_attendance atlas_planning.attendance_approval_snapshot_lines%rowtype;
  v_pantry record;
  v_prior record;
  v_line_count integer;
  v_blocker_count integer;
  v_warning_count integer;
  v_before jsonb;
  v_after jsonb;
begin
  v_error := atlas_core.rmvp_04_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;
  v_prepare := atlas_core.rmvp_04_prepare_command(
    request, v_name, 'need-generation:' || v_set_id::text
  );
  if v_prepare ->> 'status' <> 'READY' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select input_set.* into v_set
  from atlas_planning.planning_input_sets as input_set
  where input_set.planning_input_set_id = v_set_id
  for update;
  if not found or v_set.period_start <> v_start or v_set.period_end <> v_end then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'READINESS_NOT_REQUESTED',
      'The exact Planning Input Set is not ready for Need Generation.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_set.readiness_status <> 'NEED_GENERATION_REQUESTED' then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'READINESS_NOT_REQUESTED',
      'Request Need Generation from the current Planning Input Readiness decision first.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select evaluation.* into v_evaluation
  from atlas_planning.planning_input_evaluations as evaluation
  where evaluation.planning_input_evaluation_id = v_evaluation_id
    and evaluation.planning_input_set_id = v_set_id
  for update;
  if not found
    or v_set.current_evaluation_id <> v_evaluation_id
    or v_evaluation.evaluation_result <> 'READY'
    or v_evaluation.blocking_issue_count <> 0
  then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'CURRENT_EVALUATION_NOT_READY',
      'The current Planning Input Evaluation is not READY without blockers.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <>
    v_evaluation.evaluation_version
  then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'STALE_VERSION',
      'The current Planning Input Evaluation version changed.',
      false, false, '[]'::jsonb, '[]'::jsonb,
      v_evaluation.evaluation_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select run.* into v_terminal
  from atlas_planning.need_generation_runs as run
  where run.planning_input_set_id = v_set_id
  order by run.attempt_ordinal desc
  limit 1
  for update;
  if v_terminal.need_generation_run_id is not null
    and v_terminal.run_status <> 'INVALIDATED'
  then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_ALREADY_ACTIVE',
      'The exact period already has a noninvalidated terminal Need Generation run.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  v_attempt := coalesce(v_terminal.attempt_ordinal, 0) + 1;

  -- Deterministically lock the exact source roots before checking current pointers.
  perform menu.weekly_menu_id
  from atlas_planning.weekly_menus as menu
  where menu.weekly_menu_id = v_evaluation.weekly_menu_id
  order by menu.weekly_menu_id for update;
  perform attendance.attendance_batch_id
  from atlas_planning.attendance_batches as attendance
  where attendance.attendance_batch_id = v_evaluation.attendance_batch_id
  order by attendance.attendance_batch_id for update;
  perform pantry.pantry_need_batch_id
  from atlas_planning.pantry_need_batches as pantry
  where pantry.pantry_need_batch_id = v_evaluation.pantry_need_batch_id
  order by pantry.pantry_need_batch_id for update;

  if not exists (
    select 1 from atlas_planning.weekly_menus as menu
    where menu.weekly_menu_id = v_evaluation.weekly_menu_id
      and menu.version = v_evaluation.weekly_menu_version
      and menu.latest_approval_snapshot_id =
        v_evaluation.weekly_menu_approval_snapshot_id
      and menu.week_start <= v_start and menu.week_end >= v_end
      and menu.weekly_menu_status in ('APPROVED', 'NEED_GENERATION_REQUESTED')
  ) or not exists (
    select 1 from atlas_planning.attendance_batches as attendance
    where attendance.attendance_batch_id = v_evaluation.attendance_batch_id
      and attendance.version = v_evaluation.attendance_version
      and attendance.latest_approval_snapshot_id =
        v_evaluation.attendance_approval_snapshot_id
      and attendance.period_start <= v_start
      and attendance.period_end >= v_end
      and attendance.attendance_status in ('APPROVED', 'USED_FOR_NEED_GENERATION')
  ) or not exists (
    select 1 from atlas_planning.pantry_need_batches as pantry
    where pantry.pantry_need_batch_id = v_evaluation.pantry_need_batch_id
      and pantry.version = v_evaluation.pantry_need_batch_version
      and pantry.latest_approval_snapshot_id =
        v_evaluation.pantry_need_approval_snapshot_id
      and pantry.week_start <= v_start and pantry.week_end >= v_end
      and pantry.pantry_need_batch_status = 'APPROVED'
  ) then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'STALE_SOURCE_BINDING',
      'One or more approved source bindings changed after readiness evaluation.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select contract.* into v_contract
  from atlas_planning.need_generation_calculation_contracts as contract
  where contract.contract_code = 'school_catering_proportional_per_basis'
  for key share;
  if not found then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'INVARIANT_VIOLATION',
      'The approved Need Generation calculation contract is unavailable.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  for v_menu in
    select menu_line.*, school.school_type_id,
      dish.dish_status, dish.requires_need_generation,
      recipe.recipe_id, recipe.recipe_version_id,
      recipe.recipe_version_number, recipe.basis_portions,
      recipe.selection_scope, recipe.typed_eligible_count,
      recipe.general_eligible_count
    from atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
    join atlas_admin.schools as school on school.school_id = menu_line.school_id
    join atlas_admin.dishes as dish on dish.dish_id = menu_line.dish_id
    left join lateral (
      with eligible as materialized (
        select candidate.recipe_id, candidate.school_type_id,
          version.recipe_version_id,
          version.version_number as recipe_version_number,
          version.basis_portions
        from atlas_admin.recipes as candidate
        join atlas_admin.recipe_versions as version
          on version.recipe_id = candidate.recipe_id
         and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
        where candidate.dish_id = menu_line.dish_id
          and candidate.recipe_status = 'ACTIVE'
          and (candidate.school_type_id = school.school_type_id
            or candidate.school_type_id is null)
      ), candidate_counts as (
        select
          count(*) filter (
            where eligible.school_type_id = school.school_type_id
          ) as typed_eligible_count,
          count(*) filter (
            where eligible.school_type_id is null
          ) as general_eligible_count
        from eligible
      )
      select selected.recipe_id, selected.recipe_version_id,
        selected.recipe_version_number, selected.basis_portions,
        case when selected.school_type_id is null
          then 'GENERAL' else 'SCHOOL_TYPE' end as selection_scope,
        candidate_counts.typed_eligible_count,
        candidate_counts.general_eligible_count
      from candidate_counts
      left join lateral (
        select eligible.*
        from eligible
        where (
          candidate_counts.typed_eligible_count = 1
          and eligible.school_type_id = school.school_type_id
        ) or (
          candidate_counts.typed_eligible_count = 0
          and candidate_counts.general_eligible_count = 1
          and eligible.school_type_id is null
        )
      ) as selected on true
    ) as recipe on true
    where menu_line.weekly_menu_approval_snapshot_id =
      v_evaluation.weekly_menu_approval_snapshot_id
      and menu_line.service_date between v_start and v_end
    order by menu_line.service_date, menu_line.school_id,
      menu_line.weekly_menu_approval_snapshot_line_id
  loop
    if v_menu.dish_status <> 'ACTIVE' then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'INACTIVE_OR_INVALID_DISH',
          'message', 'This Menu line references a Dish that is not active.',
          'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
          'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
          'dish_id', v_menu.dish_id
        )
      );
      continue;
    end if;
    if not v_menu.requires_need_generation then
      continue;
    end if;
    if v_menu.typed_eligible_count > 1
      or (
        v_menu.typed_eligible_count = 0
        and v_menu.general_eligible_count > 1
      )
    then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'AMBIGUOUS_ELIGIBLE_RECIPE',
          'message', 'More than one released active Recipe is eligible in the selected tier for this Menu line.',
          'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
          'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
          'dish_id', v_menu.dish_id
        )
      );
      continue;
    end if;
    if v_menu.recipe_id is null then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'MISSING_ELIGIBLE_RECIPE',
          'message', 'No released active Recipe is eligible for this Menu line.',
          'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
          'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
          'dish_id', v_menu.dish_id
        )
      );
      continue;
    end if;

    v_selection_id := gen_random_uuid();
    v_selections := v_selections || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'id', v_selection_id,
        'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
        'menu_line_id', v_menu.weekly_menu_line_id,
        'school_id', v_menu.school_id,
        'school_type_id', v_menu.school_type_id,
        'dish_id', v_menu.dish_id,
        'recipe_id', v_menu.recipe_id,
        'recipe_version_id', v_menu.recipe_version_id,
        'recipe_version_number', v_menu.recipe_version_number,
        'selection_scope', v_menu.selection_scope
      )
    );

    select attendance.* into v_attendance
    from atlas_planning.attendance_approval_snapshot_lines as attendance
    where attendance.attendance_approval_snapshot_id =
      v_evaluation.attendance_approval_snapshot_id
      and attendance.school_id = v_menu.school_id
      and attendance.service_date = v_menu.service_date;

    for v_revision in
      select revision.*, ingredient.ingredient_status,
        unit.unit_status
      from atlas_admin.recipe_line_revisions as revision
      join atlas_admin.ingredients as ingredient
        on ingredient.ingredient_id = revision.ingredient_id
      join atlas_admin.units as unit on unit.unit_id = revision.unit_id
      where revision.recipe_version_id = v_menu.recipe_version_id
        and revision.recipe_id = v_menu.recipe_id
      order by revision.recipe_line_id
    loop
      v_use_id := gen_random_uuid();
      v_uses := v_uses || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', v_use_id, 'selection_id', v_selection_id,
          'recipe_id', v_menu.recipe_id,
          'recipe_version_id', v_menu.recipe_version_id,
          'recipe_line_id', v_revision.recipe_line_id,
          'recipe_line_revision_id', v_revision.recipe_line_revision_id
        )
      );
      if v_attendance.attendance_approval_snapshot_line_id is null then
        v_issues := v_issues || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', gen_random_uuid(), 'severity', 'BLOCKING',
            'code', 'MISSING_ATTENDANCE_SNAPSHOT_LINE',
            'message', 'Approved Attendance is missing for this Recipe contribution.',
            'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
            'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
            'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
            'recipe_line_id', v_revision.recipe_line_id,
            'ingredient_id', v_revision.ingredient_id,
            'unit_id', v_revision.unit_id
          )
        );
        continue;
      end if;
      if v_revision.ingredient_status <> 'ACTIVE'
        or v_revision.unit_status <> 'ACTIVE'
      then
        v_issues := v_issues || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', gen_random_uuid(), 'severity', 'BLOCKING',
            'code', case when v_revision.ingredient_status <> 'ACTIVE'
              then 'INACTIVE_OR_INVALID_INGREDIENT'
              else 'INACTIVE_OR_INVALID_UNIT' end,
            'message', 'A Recipe contribution references inactive master data.',
            'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
            'attendance_snapshot_line_id',
              v_attendance.attendance_approval_snapshot_line_id,
            'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
            'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
            'recipe_line_id', v_revision.recipe_line_id,
            'ingredient_id', v_revision.ingredient_id,
            'unit_id', v_revision.unit_id
          )
        );
        continue;
      end if;

      v_predecessor := null;
      if v_terminal.need_generation_run_id is not null then
        select prior.* into v_predecessor
        from atlas_planning.theoretical_need_lines as prior
        where prior.need_generation_run_id = v_terminal.need_generation_run_id
          and prior.contribution_family = 'RECIPE_DERIVED'
          and prior.line_disposition = 'ACTIVE'
          and prior.weekly_menu_line_id = v_menu.weekly_menu_line_id
          and prior.attendance_line_id = v_attendance.attendance_line_id
          and prior.recipe_line_id = v_revision.recipe_line_id;
      end if;

      if v_revision.line_disposition = 'PRESENT' then
        if exists (
          select 1
          from atlas_planning.theoretical_need_lines as removed
          join atlas_planning.need_generation_runs as removed_run
            on removed_run.need_generation_run_id = removed.need_generation_run_id
          where removed_run.planning_input_set_id = v_set_id
            and removed.contribution_family = 'RECIPE_DERIVED'
            and removed.line_disposition = 'REMOVED'
            and removed.weekly_menu_line_id = v_menu.weekly_menu_line_id
            and removed.attendance_line_id = v_attendance.attendance_line_id
            and removed.recipe_line_id = v_revision.recipe_line_id
        ) then
          v_issues := v_issues || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'id', gen_random_uuid(), 'severity', 'BLOCKING',
              'code', 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL',
              'message', 'This Recipe lineage was previously removed and needs separate governance.',
              'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
              'attendance_snapshot_line_id',
                v_attendance.attendance_approval_snapshot_line_id,
              'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
              'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
              'recipe_line_id', v_revision.recipe_line_id,
              'ingredient_id', v_revision.ingredient_id,
              'unit_id', v_revision.unit_id
            )
          );
          continue;
        end if;
        v_quantity := (
          (
            (
              v_attendance.student_portions::bigint
              + v_attendance.teacher_portions::bigint
            )::numeric
            * v_revision.quantity_per_basis::numeric
          ) / v_menu.basis_portions::numeric
        )::numeric(20, 6);
        v_line_id := gen_random_uuid();
        v_lines := v_lines || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', v_line_id, 'family', 'RECIPE_DERIVED',
            'selection_id', v_selection_id, 'use_id', v_use_id,
            'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
            'menu_line_id', v_menu.weekly_menu_line_id,
            'attendance_snapshot_line_id',
              v_attendance.attendance_approval_snapshot_line_id,
            'attendance_line_id', v_attendance.attendance_line_id,
            'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
            'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
            'recipe_version_id', v_menu.recipe_version_id,
            'recipe_line_id', v_revision.recipe_line_id,
            'recipe_line_revision_id', v_revision.recipe_line_revision_id,
            'ingredient_id', v_revision.ingredient_id,
            'unit_id', v_revision.unit_id,
            'predecessor_run_id', v_predecessor.need_generation_run_id,
            'predecessor_line_id', v_predecessor.theoretical_need_line_id,
            'disposition', 'ACTIVE', 'quantity', v_quantity
          )
        );
        if v_quantity = 0 then
          v_issues := v_issues || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'id', gen_random_uuid(), 'severity', 'WARNING',
              'code', 'ZERO_ACTIVE_THEORETICAL_QUANTITY',
              'message', 'This active Recipe contribution calculated to zero.',
              'theoretical_line_id', v_line_id,
              'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
              'attendance_snapshot_line_id',
                v_attendance.attendance_approval_snapshot_line_id,
              'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
              'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
              'recipe_line_id', v_revision.recipe_line_id,
              'ingredient_id', v_revision.ingredient_id,
              'unit_id', v_revision.unit_id
            )
          );
        end if;
      elsif v_predecessor.theoretical_need_line_id is not null then
        v_line_id := gen_random_uuid();
        v_lines := v_lines || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', v_line_id, 'family', 'RECIPE_DERIVED',
            'selection_id', v_selection_id, 'use_id', v_use_id,
            'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
            'menu_line_id', v_menu.weekly_menu_line_id,
            'attendance_snapshot_line_id',
              v_attendance.attendance_approval_snapshot_line_id,
            'attendance_line_id', v_attendance.attendance_line_id,
            'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
            'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
            'recipe_version_id', v_menu.recipe_version_id,
            'recipe_line_id', v_revision.recipe_line_id,
            'recipe_line_revision_id', v_revision.recipe_line_revision_id,
            'ingredient_id', v_revision.ingredient_id,
            'unit_id', v_revision.unit_id,
            'predecessor_run_id', v_predecessor.need_generation_run_id,
            'predecessor_line_id', v_predecessor.theoretical_need_line_id,
            'disposition', 'REMOVED', 'quantity', 0
          )
        );
      end if;
    end loop;
  end loop;

  for v_pantry in
    select pantry.*
    from atlas_planning.pantry_need_approval_snapshot_lines as pantry
    where pantry.pantry_need_approval_snapshot_id =
      v_evaluation.pantry_need_approval_snapshot_id
      and pantry.service_date between v_start and v_end
      and pantry.requested_quantity > 0
    order by pantry.service_date, pantry.school_id,
      pantry.pantry_need_line_id
  loop
    v_predecessor := null;
    if v_terminal.need_generation_run_id is not null then
      select prior.* into v_predecessor
      from atlas_planning.theoretical_need_lines as prior
      where prior.need_generation_run_id = v_terminal.need_generation_run_id
        and prior.contribution_family = 'PANTRY_DIRECT'
        and prior.line_disposition = 'ACTIVE'
        and prior.pantry_need_line_id = v_pantry.pantry_need_line_id;
    end if;
    if exists (
      select 1
      from atlas_planning.theoretical_need_lines as removed
      join atlas_planning.need_generation_runs as removed_run
        on removed_run.need_generation_run_id = removed.need_generation_run_id
      where removed_run.planning_input_set_id = v_set_id
        and removed.contribution_family = 'PANTRY_DIRECT'
        and removed.line_disposition = 'REMOVED'
        and removed.pantry_need_line_id = v_pantry.pantry_need_line_id
    ) then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL',
          'message', 'This Pantry lineage was previously removed and needs separate governance.',
          'school_id', v_pantry.school_id,
          'service_date', v_pantry.service_date,
          'ingredient_id', v_pantry.ingredient_id,
          'unit_id', v_pantry.unit_id,
          'pantry_snapshot_id', v_evaluation.pantry_need_approval_snapshot_id,
          'pantry_line_id', v_pantry.pantry_need_line_id,
          'pantry_active_line_id', v_pantry.pantry_need_line_id
        )
      );
      continue;
    end if;
    v_line_id := gen_random_uuid();
    v_lines := v_lines || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'id', v_line_id, 'family', 'PANTRY_DIRECT',
        'school_id', v_pantry.school_id,
        'service_date', v_pantry.service_date,
        'delivery_location_id', v_pantry.delivery_location_id,
        'ingredient_id', v_pantry.ingredient_id,
        'unit_id', v_pantry.unit_id,
        'pantry_line_id', v_pantry.pantry_need_line_id,
        'pantry_active_line_id', v_pantry.pantry_need_line_id,
        'predecessor_run_id', v_predecessor.need_generation_run_id,
        'predecessor_line_id', v_predecessor.theoretical_need_line_id,
        'disposition', 'ACTIVE',
        'quantity', v_pantry.requested_quantity
      )
    );
    if v_predecessor.theoretical_need_line_id is not null
      and (v_predecessor.school_id, v_predecessor.service_date,
        v_predecessor.delivery_location_id, v_predecessor.ingredient_id,
        v_predecessor.unit_id) is distinct from
        (v_pantry.school_id, v_pantry.service_date,
        v_pantry.delivery_location_id, v_pantry.ingredient_id,
        v_pantry.unit_id)
    then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'INVALID_PREDECESSOR',
          'message', 'The Pantry correction changed a fixed operational anchor.',
          'theoretical_line_id', v_line_id,
          'school_id', v_pantry.school_id,
          'service_date', v_pantry.service_date,
          'ingredient_id', v_pantry.ingredient_id,
          'unit_id', v_pantry.unit_id,
          'pantry_snapshot_id', v_evaluation.pantry_need_approval_snapshot_id,
          'pantry_line_id', v_pantry.pantry_need_line_id,
          'pantry_active_line_id', v_pantry.pantry_need_line_id
        )
      );
    end if;
  end loop;

  if v_terminal.need_generation_run_id is not null then
    for v_prior in
      select prior.*
      from atlas_planning.theoretical_need_lines as prior
      where prior.need_generation_run_id = v_terminal.need_generation_run_id
        and prior.line_disposition = 'ACTIVE'
        and not exists (
          select 1 from pg_catalog.jsonb_array_elements(v_lines) as item
          where atlas_core.pa_05b_safe_uuid(
            item ->> 'predecessor_line_id'
          ) = prior.theoretical_need_line_id
        )
      order by prior.contribution_family, prior.theoretical_need_line_id
    loop
      if v_prior.contribution_family = 'PANTRY_DIRECT' then
        v_lines := v_lines || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', gen_random_uuid(), 'family', 'PANTRY_DIRECT',
            'school_id', v_prior.school_id,
            'service_date', v_prior.service_date,
            'delivery_location_id', v_prior.delivery_location_id,
            'ingredient_id', v_prior.ingredient_id,
            'unit_id', v_prior.unit_id,
            'pantry_line_id', v_prior.pantry_need_line_id,
            'predecessor_run_id', v_terminal.need_generation_run_id,
            'predecessor_line_id', v_prior.theoretical_need_line_id,
            'disposition', 'REMOVED', 'quantity', 0
          )
        );
      else
        v_issues := v_issues || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', gen_random_uuid(), 'severity', 'BLOCKING',
            'code', 'SILENT_PREDECESSOR_OMISSION',
            'message', 'A prior Recipe contribution has no typed successor or removal.',
            'school_id', v_prior.school_id,
            'service_date', v_prior.service_date,
            'dish_id', v_prior.dish_id,
            'recipe_id', v_prior.recipe_id,
            'recipe_line_id', v_prior.recipe_line_id,
            'ingredient_id', v_prior.ingredient_id,
            'unit_id', v_prior.unit_id
          )
        );
      end if;
    end loop;
  end if;

  v_line_count := pg_catalog.jsonb_array_length(v_lines);
  select count(*) filter (where item ->> 'severity' = 'BLOCKING'),
    count(*) filter (where item ->> 'severity' = 'WARNING')
  into v_blocker_count, v_warning_count
  from pg_catalog.jsonb_array_elements(v_issues) as item;

  insert into atlas_planning.need_generation_runs (
    need_generation_run_id, planning_input_set_id,
    planning_input_evaluation_id, evaluation_version,
    period_start, period_end, attempt_ordinal,
    predecessor_need_generation_run_id, input_snapshot_id,
    run_status, version, generated_line_count, blocking_issue_count,
    warning_count, generated_by_actor_id, generated_at, updated_at
  ) values (
    v_run_id, v_set_id, v_evaluation_id, v_evaluation.evaluation_version,
    v_start, v_end, v_attempt, v_terminal.need_generation_run_id,
    v_snapshot_id, 'GENERATED', 1, v_line_count, v_blocker_count,
    v_warning_count, v_actor_id, v_now, v_now
  );

  insert into atlas_planning.need_generation_input_snapshots (
    need_generation_input_snapshot_id, need_generation_run_id,
    planning_input_set_id, planning_input_evaluation_id, evaluation_version,
    weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id,
    attendance_batch_id, attendance_version, attendance_approval_snapshot_id,
    need_generation_calculation_contract_id,
    need_generation_calculation_contract_revision_id,
    calculation_contract_revision_number, captured_at,
    pantry_need_batch_id, pantry_need_batch_version,
    pantry_need_approval_snapshot_id
  ) values (
    v_snapshot_id, v_run_id, v_set_id, v_evaluation_id,
    v_evaluation.evaluation_version, v_evaluation.weekly_menu_id,
    v_evaluation.weekly_menu_version,
    v_evaluation.weekly_menu_approval_snapshot_id,
    v_evaluation.attendance_batch_id, v_evaluation.attendance_version,
    v_evaluation.attendance_approval_snapshot_id,
    v_contract.need_generation_calculation_contract_id,
    v_contract.current_revision_id, v_contract.version, v_now,
    v_evaluation.pantry_need_batch_id,
    v_evaluation.pantry_need_batch_version,
    v_evaluation.pantry_need_approval_snapshot_id
  );

  insert into atlas_planning.need_generation_recipe_selections (
    need_generation_recipe_selection_id, need_generation_input_snapshot_id,
    need_generation_run_id, weekly_menu_approval_snapshot_line_id,
    weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
    weekly_menu_line_id, school_id, school_type_id, dish_id, recipe_id,
    recipe_version_id, recipe_version_number, selection_scope, selected_at
  )
  select item.id, v_snapshot_id, v_run_id, item.menu_snapshot_line_id,
    v_evaluation.weekly_menu_approval_snapshot_id,
    v_evaluation.weekly_menu_id, v_evaluation.weekly_menu_version,
    item.menu_line_id, item.school_id, item.school_type_id, item.dish_id,
    item.recipe_id, item.recipe_version_id, item.recipe_version_number,
    item.selection_scope, v_now
  from pg_catalog.jsonb_to_recordset(v_selections) as item(
    id uuid, menu_snapshot_line_id uuid, menu_line_id uuid, school_id uuid,
    school_type_id uuid, dish_id uuid, recipe_id uuid,
    recipe_version_id uuid, recipe_version_number integer,
    selection_scope text
  );

  insert into atlas_planning.need_generation_recipe_line_uses (
    need_generation_recipe_line_use_id, need_generation_input_snapshot_id,
    need_generation_run_id, need_generation_recipe_selection_id,
    recipe_id, recipe_version_id, recipe_line_id,
    recipe_line_revision_id, captured_at
  )
  select item.id, v_snapshot_id, v_run_id, item.selection_id,
    item.recipe_id, item.recipe_version_id, item.recipe_line_id,
    item.recipe_line_revision_id, v_now
  from pg_catalog.jsonb_to_recordset(v_uses) as item(
    id uuid, selection_id uuid, recipe_id uuid, recipe_version_id uuid,
    recipe_line_id uuid, recipe_line_revision_id uuid
  );

  insert into atlas_planning.theoretical_need_lines (
    theoretical_need_line_id, need_generation_run_id,
    need_generation_input_snapshot_id, need_generation_recipe_selection_id,
    need_generation_recipe_line_use_id,
    weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id,
    weekly_menu_id, weekly_menu_version, weekly_menu_line_id,
    attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
    attendance_batch_id, attendance_version, attendance_line_id,
    school_id, service_date, dish_id, recipe_id, recipe_version_id,
    recipe_line_id, recipe_line_revision_id, ingredient_id, unit_id,
    need_generation_calculation_contract_id,
    need_generation_calculation_contract_revision_id,
    calculation_contract_revision_number,
    predecessor_need_generation_run_id, predecessor_theoretical_need_line_id,
    line_disposition, theoretical_quantity, created_at,
    contribution_family, delivery_location_id, pantry_need_batch_id,
    pantry_need_batch_version, pantry_need_approval_snapshot_id,
    pantry_need_line_id, pantry_active_snapshot_member_line_id
  )
  select item.id, v_run_id, v_snapshot_id,
    item.selection_id, item.use_id, item.menu_snapshot_line_id,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.weekly_menu_approval_snapshot_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.weekly_menu_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.weekly_menu_version end,
    item.menu_line_id, item.attendance_snapshot_line_id,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.attendance_approval_snapshot_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.attendance_batch_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.attendance_version end,
    item.attendance_line_id, item.school_id, item.service_date,
    item.dish_id, item.recipe_id, item.recipe_version_id,
    item.recipe_line_id, item.recipe_line_revision_id,
    item.ingredient_id, item.unit_id,
    case when item.family = 'RECIPE_DERIVED'
      then v_contract.need_generation_calculation_contract_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_contract.current_revision_id end,
    case when item.family = 'RECIPE_DERIVED' then v_contract.version end,
    item.predecessor_run_id, item.predecessor_line_id,
    item.disposition, item.quantity, v_now, item.family,
    item.delivery_location_id,
    case when item.family = 'PANTRY_DIRECT'
      then v_evaluation.pantry_need_batch_id end,
    case when item.family = 'PANTRY_DIRECT'
      then v_evaluation.pantry_need_batch_version end,
    case when item.family = 'PANTRY_DIRECT'
      then v_evaluation.pantry_need_approval_snapshot_id end,
    item.pantry_line_id, item.pantry_active_line_id
  from pg_catalog.jsonb_to_recordset(v_lines) as item(
    id uuid, family text, selection_id uuid, use_id uuid,
    menu_snapshot_line_id uuid, menu_line_id uuid,
    attendance_snapshot_line_id uuid, attendance_line_id uuid,
    school_id uuid, service_date date, dish_id uuid, recipe_id uuid,
    recipe_version_id uuid, recipe_line_id uuid,
    recipe_line_revision_id uuid, ingredient_id uuid, unit_id uuid,
    predecessor_run_id uuid, predecessor_line_id uuid,
    disposition text, quantity numeric(20, 6), delivery_location_id uuid,
    pantry_line_id uuid, pantry_active_line_id uuid
  );

  insert into atlas_planning.need_generation_issues (
    need_generation_issue_id, need_generation_run_id,
    theoretical_need_line_id, severity, issue_code, message,
    weekly_menu_approval_snapshot_line_id,
    attendance_approval_snapshot_line_id, school_id, service_date,
    dish_id, recipe_id, recipe_line_id, ingredient_id, unit_id, created_at,
    pantry_need_approval_snapshot_id, pantry_need_line_id,
    pantry_active_snapshot_member_line_id
  )
  select item.id, v_run_id, item.theoretical_line_id,
    item.severity, item.code, item.message, item.menu_snapshot_line_id,
    item.attendance_snapshot_line_id, item.school_id, item.service_date,
    item.dish_id, item.recipe_id, item.recipe_line_id,
    item.ingredient_id, item.unit_id, v_now, item.pantry_snapshot_id,
    item.pantry_line_id, item.pantry_active_line_id
  from pg_catalog.jsonb_to_recordset(v_issues) as item(
    id uuid, theoretical_line_id uuid, severity text, code text,
    message text, menu_snapshot_line_id uuid,
    attendance_snapshot_line_id uuid, school_id uuid, service_date date,
    dish_id uuid, recipe_id uuid, recipe_line_id uuid,
    ingredient_id uuid, unit_id uuid, pantry_snapshot_id uuid,
    pantry_line_id uuid, pantry_active_line_id uuid
  );

  set constraints all immediate;
  set constraints all deferred;

  v_before := pg_catalog.jsonb_build_object(
    'planning_input_evaluation_id', v_evaluation_id,
    'evaluation_version', v_evaluation.evaluation_version,
    'terminal_need_generation_run_id', v_terminal.need_generation_run_id
  );
  v_after := pg_catalog.jsonb_build_object(
    'need_generation_run_id', v_run_id,
    'attempt_ordinal', v_attempt, 'status', 'GENERATED', 'version', 1,
    'generated_line_count', v_line_count,
    'blocking_issue_count', v_blocker_count,
    'warning_count', v_warning_count
  );
  return atlas_core.rmvp_04_success(
    request, v_actor_id, v_receipt_id, 'NeedGenerationCreated',
    v_run_id, null, 1, 'Need Generation was created from exact approved inputs.',
    v_before, v_after
  );
exception when serialization_failure or deadlock_detected then
  return atlas_core.rmvp_04_error(
    request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Need Generation evidence is being updated. Retry the exact unchanged request.',
    false, true
  );
when others then
  return atlas_core.rmvp_04_error(
    request, v_name, 'INVARIANT_VIOLATION',
    'Need Generation could not be created safely.'
  );
end;
$$;

create function atlas_api.validate_need_generation_run(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'validate_need_generation_run';
  v_error jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_run_id uuid := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'need_generation_run_id'
  );
  v_run atlas_planning.need_generation_runs%rowtype;
  v_terminal_id uuid;
  v_before jsonb;
  v_after jsonb;
begin
  v_error := atlas_core.rmvp_04_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;
  v_prepare := atlas_core.rmvp_04_prepare_command(
    request, v_name, 'need-generation-run:' || v_run_id::text
  );
  if v_prepare ->> 'status' <> 'READY' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select run.* into v_run
  from atlas_planning.need_generation_runs as run
  where run.need_generation_run_id = v_run_id
  for update;
  if not found then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_NOT_FOUND',
      'The Need Generation run was not found.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  select terminal.need_generation_run_id into v_terminal_id
  from atlas_planning.need_generation_runs as terminal
  where terminal.planning_input_set_id = v_run.planning_input_set_id
  order by terminal.attempt_ordinal desc limit 1;
  if v_terminal_id <> v_run_id then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_NOT_TERMINAL',
      'Only the terminal Need Generation run can be validated.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_run.run_status <> 'GENERATED' then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_NOT_GENERATED',
      'Only a generated Need Generation run can be validated.',
      false, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <>
    v_run.version
  then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'STALE_VERSION',
      'The Need Generation run version changed.',
      false, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_run.blocking_issue_count > 0 then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_HAS_BLOCKERS',
      'Resolve blocking issues through corrected source evidence before validation.',
      false, false, '[]'::jsonb,
      (select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'issue_code', issue.issue_code,
          'need_generation_issue_id', issue.need_generation_issue_id
        ) order by issue.created_at
      ), '[]'::jsonb)
      from atlas_planning.need_generation_issues as issue
      where issue.need_generation_run_id = v_run_id
        and issue.severity = 'BLOCKING'), v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'status', v_run.run_status, 'version', v_run.version
  );
  update atlas_planning.need_generation_runs as run
  set run_status = 'VALIDATED', version = run.version + 1,
    validated_by_actor_id = v_actor_id,
    validated_at = pg_catalog.transaction_timestamp(),
    updated_at = pg_catalog.transaction_timestamp()
  where run.need_generation_run_id = v_run_id;
  set constraints all immediate;
  set constraints all deferred;
  v_after := pg_catalog.jsonb_build_object(
    'status', 'VALIDATED', 'version', v_run.version + 1
  );
  return atlas_core.rmvp_04_success(
    request, v_actor_id, v_receipt_id, 'NeedGenerationValidated',
    v_run_id, v_run.version, v_run.version + 1,
    'Need Generation passed validation.', v_before, v_after
  );
exception when serialization_failure or deadlock_detected then
  return atlas_core.rmvp_04_error(
    request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Need Generation is being updated. Retry the exact unchanged request.',
    false, true
  );
when others then
  return atlas_core.rmvp_04_error(
    request, v_name, 'INVARIANT_VIOLATION',
    'Need Generation could not be validated safely.'
  );
end;
$$;

create function atlas_api.release_need_generation_run(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'release_need_generation_run';
  v_error jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_run_id uuid := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'need_generation_run_id'
  );
  v_run atlas_planning.need_generation_runs%rowtype;
  v_terminal_id uuid;
  v_release_id uuid := gen_random_uuid();
  v_new_version bigint;
  v_before jsonb;
  v_after jsonb;
begin
  v_error := atlas_core.rmvp_04_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;
  v_prepare := atlas_core.rmvp_04_prepare_command(
    request, v_name, 'need-generation-run:' || v_run_id::text
  );
  if v_prepare ->> 'status' <> 'READY' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select run.* into v_run
  from atlas_planning.need_generation_runs as run
  where run.need_generation_run_id = v_run_id
  for update;
  if not found then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_NOT_FOUND',
      'The Need Generation run was not found.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  select terminal.need_generation_run_id into v_terminal_id
  from atlas_planning.need_generation_runs as terminal
  where terminal.planning_input_set_id = v_run.planning_input_set_id
  order by terminal.attempt_ordinal desc limit 1;
  if v_terminal_id <> v_run_id then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_NOT_TERMINAL',
      'Only the terminal Need Generation run can be released.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_run.run_status <> 'VALIDATED' then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_NOT_VALIDATED',
      'Validate the terminal Need Generation run before release.',
      false, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <>
    v_run.version
  then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'STALE_VERSION',
      'The Need Generation run version changed.',
      false, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_run.blocking_issue_count > 0 then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_HAS_BLOCKERS',
      'A Need Generation run with blockers cannot be released.',
      false, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  v_new_version := v_run.version + 1;
  v_before := pg_catalog.jsonb_build_object(
    'status', v_run.run_status, 'version', v_run.version
  );
  update atlas_planning.need_generation_runs as run
  set run_status = 'RELEASED_FOR_CONFIRMATION', version = v_new_version,
    released_by_actor_id = v_actor_id,
    released_at = pg_catalog.transaction_timestamp(),
    updated_at = pg_catalog.transaction_timestamp()
  where run.need_generation_run_id = v_run_id;
  insert into atlas_planning.need_generation_release_snapshots (
    need_generation_release_snapshot_id, need_generation_run_id,
    released_run_version, need_generation_input_snapshot_id,
    released_by_actor_id, released_at, generated_line_count,
    active_line_count, removed_line_count, blocking_issue_count,
    warning_count
  )
  select v_release_id, v_run_id, v_new_version, v_run.input_snapshot_id,
    v_actor_id, pg_catalog.transaction_timestamp(), v_run.generated_line_count,
    count(*) filter (where line.line_disposition = 'ACTIVE'),
    count(*) filter (where line.line_disposition = 'REMOVED'),
    v_run.blocking_issue_count, v_run.warning_count
  from atlas_planning.theoretical_need_lines as line
  where line.need_generation_run_id = v_run_id;
  insert into atlas_planning.need_generation_release_snapshot_lines (
    need_generation_release_snapshot_id, need_generation_run_id,
    released_run_version, theoretical_need_line_id
  )
  select v_release_id, v_run_id, v_new_version,
    line.theoretical_need_line_id
  from atlas_planning.theoretical_need_lines as line
  where line.need_generation_run_id = v_run_id;
  insert into atlas_planning.need_generation_release_snapshot_issues (
    need_generation_release_snapshot_id, need_generation_run_id,
    released_run_version, need_generation_issue_id
  )
  select v_release_id, v_run_id, v_new_version,
    issue.need_generation_issue_id
  from atlas_planning.need_generation_issues as issue
  where issue.need_generation_run_id = v_run_id;
  set constraints all immediate;
  set constraints all deferred;
  v_after := pg_catalog.jsonb_build_object(
    'status', 'RELEASED_FOR_CONFIRMATION', 'version', v_new_version,
    'need_generation_release_snapshot_id', v_release_id
  );
  return atlas_core.rmvp_04_success(
    request, v_actor_id, v_receipt_id, 'NeedGenerationReleased',
    v_run_id, v_run.version, v_new_version,
    'Need Generation was released for Confirmed Need.',
    v_before, v_after, v_release_id
  );
exception when serialization_failure or deadlock_detected then
  return atlas_core.rmvp_04_error(
    request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Need Generation is being updated. Retry the exact unchanged request.',
    false, true
  );
when others then
  return atlas_core.rmvp_04_error(
    request, v_name, 'INVARIANT_VIOLATION',
    'Need Generation could not be released safely.'
  );
end;
$$;

create function atlas_api.invalidate_need_generation_run(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'invalidate_need_generation_run';
  v_error jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_run_id uuid := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'need_generation_run_id'
  );
  v_run atlas_planning.need_generation_runs%rowtype;
  v_terminal_id uuid;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_before jsonb;
  v_after jsonb;
begin
  v_error := atlas_core.rmvp_04_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;
  v_prepare := atlas_core.rmvp_04_prepare_command(
    request, v_name, 'need-generation-run:' || v_run_id::text
  );
  if v_prepare ->> 'status' <> 'READY' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select run.* into v_run
  from atlas_planning.need_generation_runs as run
  where run.need_generation_run_id = v_run_id
  for update;
  if not found then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_NOT_FOUND',
      'The Need Generation run was not found.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  select terminal.need_generation_run_id into v_terminal_id
  from atlas_planning.need_generation_runs as terminal
  where terminal.planning_input_set_id = v_run.planning_input_set_id
  order by terminal.attempt_ordinal desc limit 1;
  if v_terminal_id <> v_run_id then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_NOT_TERMINAL',
      'Only the terminal Need Generation run can be invalidated.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_run.run_status not in (
    'GENERATED', 'VALIDATED', 'RELEASED_FOR_CONFIRMATION'
  ) then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_NOT_TERMINAL',
      'This terminal Need Generation run cannot be invalidated.',
      false, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <>
    v_run.version
  then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'STALE_VERSION',
      'The Need Generation run version changed.',
      false, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_run.run_status = 'RELEASED_FOR_CONFIRMATION' then
    select batch.* into v_batch
    from atlas_planning.confirmed_need_batches as batch
    where batch.source_kind = 'NEED_GENERATION'
      and (batch.current_need_generation_run_id = v_run_id
        or batch.origin_need_generation_run_id in (
          select chain.need_generation_run_id
          from atlas_planning.need_generation_runs as chain
          where chain.planning_input_set_id = v_run.planning_input_set_id
        ))
    order by batch.updated_at desc
    limit 1
    for update;
    if v_batch.confirmed_need_batch_id is not null
      and (v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED')
        or exists (
          select 1
          from atlas_planning.purchase_handoff_batches as handoff
          where handoff.confirmed_need_batch_id =
            v_batch.confirmed_need_batch_id
            and handoff.handoff_status not in ('INVALIDATED', 'REOPENED')
        ))
    then
      v_error := atlas_core.rmvp_04_error(
        request, v_name, 'DOWNSTREAM_CORRECTION_REQUIRED',
        'Downstream commitment requires a separate controlled correction.',
        false, false, '[]'::jsonb,
        pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'confirmed_need_batch_id', v_batch.confirmed_need_batch_id,
          'confirmed_need_status', v_batch.batch_status
        )), v_run.version
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'status', v_run.run_status, 'version', v_run.version
  );
  update atlas_planning.need_generation_runs as run
  set run_status = 'INVALIDATED', version = run.version + 1,
    invalidated_by_actor_id = v_actor_id,
    invalidated_at = pg_catalog.transaction_timestamp(),
    updated_at = pg_catalog.transaction_timestamp()
  where run.need_generation_run_id = v_run_id;
  set constraints all immediate;
  set constraints all deferred;
  v_after := pg_catalog.jsonb_build_object(
    'status', 'INVALIDATED', 'version', v_run.version + 1,
    'reason_code', request ->> 'reason_code'
  );
  return atlas_core.rmvp_04_success(
    request, v_actor_id, v_receipt_id, 'NeedGenerationInvalidated',
    v_run_id, v_run.version, v_run.version + 1,
    'Need Generation was invalidated without rewriting history.',
    v_before, v_after
  );
exception when serialization_failure or deadlock_detected then
  return atlas_core.rmvp_04_error(
    request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Need Generation is being updated. Retry the exact unchanged request.',
    false, true
  );
when others then
  return atlas_core.rmvp_04_error(
    request, v_name, 'INVARIANT_VIOLATION',
    'Need Generation could not be invalidated safely.'
  );
end;
$$;

create function atlas_api.get_need_generation_workbench(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_need_generation_workbench';
  v_error jsonb;
  v_context jsonb;
  v_payload jsonb := request -> 'payload';
  v_workbench jsonb;
begin
  v_error := atlas_core.rmvp_04_validate_read(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_04_authorize_global(
    request, 'planning.inputs.read', v_name, true
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_workbench := atlas_core.rmvp_04_workbench_payload(
    atlas_core.rmvp_04_safe_date(v_payload ->> 'period_start'),
    atlas_core.rmvp_04_safe_date(v_payload ->> 'period_end'),
    atlas_core.pa_05b_safe_uuid(v_payload ->> 'need_generation_run_id'),
    coalesce(v_payload -> 'filters', '{}'::jsonb),
    coalesce(atlas_core.pa_05b_safe_bigint(
      v_payload ->> 'group_offset'
    )::integer, 0),
    coalesce(atlas_core.pa_05b_safe_bigint(
      v_payload ->> 'group_limit'
    )::integer, 100),
    v_payload -> 'detail_group'
  );
  if v_workbench ? 'validation_error' then
    return atlas_core.rmvp_04_error(
      request, v_name, 'VALIDATION_FAILED',
      'The selected Need Generation run does not belong to this exact period.',
      true
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-04.v1',
    'correlation_id', request ->> 'correlation_id',
    'workbench', v_workbench
  );
exception when others then
  return atlas_core.rmvp_04_error(
    request, v_name, 'INTERNAL_READ_FAILURE',
    'The Need Generation workbench could not be returned safely.', true
  );
end;
$$;

reset role;

grant usage on schema atlas_core, atlas_admin, atlas_planning, atlas_audit,
  atlas_api to atlas_need_generation_runtime;

grant select on
  atlas_core.actors,
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes,
  atlas_core.command_receipts,
  atlas_admin.customers,
  atlas_admin.schools,
  atlas_admin.delivery_locations,
  atlas_admin.ingredients,
  atlas_admin.units,
  atlas_admin.dishes,
  atlas_admin.recipes,
  atlas_admin.recipe_versions,
  atlas_admin.recipe_lines,
  atlas_admin.recipe_line_revisions,
  atlas_planning.weekly_menus,
  atlas_planning.weekly_menu_lines,
  atlas_planning.weekly_menu_approval_snapshots,
  atlas_planning.weekly_menu_approval_snapshot_lines,
  atlas_planning.attendance_batches,
  atlas_planning.attendance_lines,
  atlas_planning.attendance_approval_snapshots,
  atlas_planning.attendance_approval_snapshot_lines,
  atlas_planning.pantry_need_purposes,
  atlas_planning.pantry_need_batches,
  atlas_planning.pantry_need_lines,
  atlas_planning.pantry_need_approval_snapshots,
  atlas_planning.pantry_need_approval_snapshot_lines,
  atlas_planning.planning_input_sets,
  atlas_planning.planning_input_evaluations,
  atlas_planning.planning_input_evaluation_issues,
  atlas_planning.need_generation_calculation_contracts,
  atlas_planning.need_generation_calculation_contract_revisions,
  atlas_planning.need_generation_runs,
  atlas_planning.need_generation_input_snapshots,
  atlas_planning.need_generation_recipe_selections,
  atlas_planning.need_generation_recipe_line_uses,
  atlas_planning.theoretical_need_lines,
  atlas_planning.need_generation_issues,
  atlas_planning.need_generation_release_snapshots,
  atlas_planning.need_generation_release_snapshot_lines,
  atlas_planning.need_generation_release_snapshot_issues,
  atlas_planning.confirmed_need_batches,
  atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_line_revision_contributions,
  atlas_planning.purchase_handoff_batches
to atlas_need_generation_runtime;

grant insert, update on atlas_core.command_receipts
to atlas_need_generation_runtime;
grant insert on
  atlas_planning.need_generation_runs,
  atlas_planning.need_generation_input_snapshots,
  atlas_planning.need_generation_recipe_selections,
  atlas_planning.need_generation_recipe_line_uses,
  atlas_planning.theoretical_need_lines,
  atlas_planning.need_generation_issues,
  atlas_planning.need_generation_release_snapshots,
  atlas_planning.need_generation_release_snapshot_lines,
  atlas_planning.need_generation_release_snapshot_issues,
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_need_generation_runtime;
grant update (
  run_status, version, blocking_issue_count, warning_count,
  validated_by_actor_id, validated_at, released_by_actor_id, released_at,
  invalidated_by_actor_id, invalidated_at, updated_at
) on atlas_planning.need_generation_runs to atlas_need_generation_runtime;

-- These key-only UPDATE grants permit deterministic SELECT FOR UPDATE locks.
-- No application statement or RLS policy permits those source facts to change.
grant update (planning_input_set_id) on atlas_planning.planning_input_sets
  to atlas_need_generation_runtime;
grant update (planning_input_evaluation_id)
  on atlas_planning.planning_input_evaluations
  to atlas_need_generation_runtime;
grant update (weekly_menu_id) on atlas_planning.weekly_menus
  to atlas_need_generation_runtime;
grant update (attendance_batch_id) on atlas_planning.attendance_batches
  to atlas_need_generation_runtime;
grant update (pantry_need_batch_id) on atlas_planning.pantry_need_batches
  to atlas_need_generation_runtime;
grant update (need_generation_calculation_contract_id)
  on atlas_planning.need_generation_calculation_contracts
  to atlas_need_generation_runtime;
grant update (confirmed_need_batch_id)
  on atlas_planning.confirmed_need_batches
  to atlas_need_generation_runtime;

grant select (domain_event_id) on atlas_audit.domain_events
  to atlas_need_generation_runtime;
grant select (audit_event_id) on atlas_audit.audit_events
  to atlas_need_generation_runtime;

do $$
declare
  relation_name text;
  relations constant text[] := array[
    'atlas_core.actors',
    'atlas_core.actor_auth_subjects',
    'atlas_core.roles',
    'atlas_core.capabilities',
    'atlas_core.role_capabilities',
    'atlas_core.actor_role_memberships',
    'atlas_core.actor_scopes',
    'atlas_core.command_receipts',
    'atlas_admin.customers',
    'atlas_admin.schools',
    'atlas_admin.delivery_locations',
    'atlas_admin.ingredients',
    'atlas_admin.units',
    'atlas_admin.dishes',
    'atlas_admin.recipes',
    'atlas_admin.recipe_versions',
    'atlas_admin.recipe_lines',
    'atlas_admin.recipe_line_revisions',
    'atlas_planning.weekly_menus',
    'atlas_planning.weekly_menu_lines',
    'atlas_planning.weekly_menu_approval_snapshots',
    'atlas_planning.weekly_menu_approval_snapshot_lines',
    'atlas_planning.attendance_batches',
    'atlas_planning.attendance_lines',
    'atlas_planning.attendance_approval_snapshots',
    'atlas_planning.attendance_approval_snapshot_lines',
    'atlas_planning.pantry_need_purposes',
    'atlas_planning.pantry_need_batches',
    'atlas_planning.pantry_need_lines',
    'atlas_planning.pantry_need_approval_snapshots',
    'atlas_planning.pantry_need_approval_snapshot_lines',
    'atlas_planning.planning_input_sets',
    'atlas_planning.planning_input_evaluations',
    'atlas_planning.planning_input_evaluation_issues',
    'atlas_planning.need_generation_calculation_contracts',
    'atlas_planning.need_generation_calculation_contract_revisions',
    'atlas_planning.need_generation_runs',
    'atlas_planning.need_generation_input_snapshots',
    'atlas_planning.need_generation_recipe_selections',
    'atlas_planning.need_generation_recipe_line_uses',
    'atlas_planning.theoretical_need_lines',
    'atlas_planning.need_generation_issues',
    'atlas_planning.need_generation_release_snapshots',
    'atlas_planning.need_generation_release_snapshot_lines',
    'atlas_planning.need_generation_release_snapshot_issues',
    'atlas_planning.confirmed_need_batches',
    'atlas_planning.confirmed_need_lines',
    'atlas_planning.confirmed_need_line_revisions',
    'atlas_planning.confirmed_need_line_revision_contributions',
    'atlas_planning.purchase_handoff_batches'
  ];
begin
  foreach relation_name in array relations loop
    execute pg_catalog.format(
      'create policy rmvp_04_need_generation_select on %s for select to atlas_need_generation_runtime using (true)',
      relation_name
    );
  end loop;
end
$$;

-- PostgreSQL applies UPDATE USING policies to SELECT locking clauses under
-- forced RLS. These policies make the exact source rows lockable while the
-- false WITH CHECK keeps every direct source UPDATE forbidden.
create policy rmvp_04_need_generation_input_set_lock
on atlas_planning.planning_input_sets
for update to atlas_need_generation_runtime using (true) with check (false);
create policy rmvp_04_need_generation_evaluation_lock
on atlas_planning.planning_input_evaluations
for update to atlas_need_generation_runtime using (true) with check (false);
create policy rmvp_04_need_generation_menu_lock
on atlas_planning.weekly_menus
for update to atlas_need_generation_runtime using (true) with check (false);
create policy rmvp_04_need_generation_attendance_lock
on atlas_planning.attendance_batches
for update to atlas_need_generation_runtime using (true) with check (false);
create policy rmvp_04_need_generation_pantry_lock
on atlas_planning.pantry_need_batches
for update to atlas_need_generation_runtime using (true) with check (false);
create policy rmvp_04_need_generation_contract_lock
on atlas_planning.need_generation_calculation_contracts
for update to atlas_need_generation_runtime using (true) with check (false);
create policy rmvp_04_need_generation_confirmed_need_lock
on atlas_planning.confirmed_need_batches
for update to atlas_need_generation_runtime using (true) with check (false);

create policy rmvp_04_need_generation_receipt_insert
on atlas_core.command_receipts for insert to atlas_need_generation_runtime
with check (true);
create policy rmvp_04_need_generation_receipt_update
on atlas_core.command_receipts for update to atlas_need_generation_runtime
using (true) with check (true);
create policy rmvp_04_need_generation_run_insert
on atlas_planning.need_generation_runs for insert to atlas_need_generation_runtime
with check (true);
create policy rmvp_04_need_generation_run_update
on atlas_planning.need_generation_runs for update to atlas_need_generation_runtime
using (true) with check (true);
create policy rmvp_04_need_generation_snapshot_insert
on atlas_planning.need_generation_input_snapshots
for insert to atlas_need_generation_runtime with check (true);
create policy rmvp_04_need_generation_selection_insert
on atlas_planning.need_generation_recipe_selections
for insert to atlas_need_generation_runtime with check (true);
create policy rmvp_04_need_generation_use_insert
on atlas_planning.need_generation_recipe_line_uses
for insert to atlas_need_generation_runtime with check (true);
create policy rmvp_04_need_generation_line_insert
on atlas_planning.theoretical_need_lines
for insert to atlas_need_generation_runtime with check (true);
create policy rmvp_04_need_generation_issue_insert
on atlas_planning.need_generation_issues
for insert to atlas_need_generation_runtime with check (true);
create policy rmvp_04_need_generation_release_insert
on atlas_planning.need_generation_release_snapshots
for insert to atlas_need_generation_runtime with check (true);
create policy rmvp_04_need_generation_release_line_insert
on atlas_planning.need_generation_release_snapshot_lines
for insert to atlas_need_generation_runtime with check (true);
create policy rmvp_04_need_generation_release_issue_insert
on atlas_planning.need_generation_release_snapshot_issues
for insert to atlas_need_generation_runtime with check (true);
create policy rmvp_04_need_generation_domain_event_insert
on atlas_audit.domain_events for insert to atlas_need_generation_runtime
with check (true);
create policy rmvp_04_need_generation_audit_event_insert
on atlas_audit.audit_events for insert to atlas_need_generation_runtime
with check (true);
create policy rmvp_04_need_generation_domain_event_select
on atlas_audit.domain_events for select to atlas_need_generation_runtime
using (true);
create policy rmvp_04_need_generation_audit_event_select
on atlas_audit.audit_events for select to atlas_need_generation_runtime
using (true);

revoke execute on function
  atlas_core.rmvp_04_safe_date(text),
  atlas_core.rmvp_04_error(
    jsonb, text, text, text, boolean, boolean, jsonb, jsonb, bigint
  ),
  atlas_core.rmvp_04_authorize_global(jsonb, text, text, boolean),
  atlas_core.rmvp_04_validate_read(jsonb, text),
  atlas_core.rmvp_04_validate_command(jsonb, text),
  atlas_core.rmvp_04_prepare_command(jsonb, text, text),
  atlas_core.rmvp_04_record_change(
    jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb
  ),
  atlas_core.rmvp_04_workbench_payload(
    date, date, uuid, jsonb, integer, integer, jsonb
  ),
  atlas_core.rmvp_04_success(
    jsonb, uuid, uuid, text, uuid, bigint, bigint, text, jsonb, jsonb, uuid
  )
from public, anon, authenticated, service_role;

grant execute on function
  atlas_core.rmvp_04_safe_date(text),
  atlas_core.rmvp_04_error(
    jsonb, text, text, text, boolean, boolean, jsonb, jsonb, bigint
  ),
  atlas_core.rmvp_04_authorize_global(jsonb, text, text, boolean),
  atlas_core.rmvp_04_validate_read(jsonb, text),
  atlas_core.rmvp_04_validate_command(jsonb, text),
  atlas_core.rmvp_04_prepare_command(jsonb, text, text),
  atlas_core.rmvp_04_record_change(
    jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb
  ),
  atlas_core.rmvp_04_workbench_payload(
    date, date, uuid, jsonb, integer, integer, jsonb
  ),
  atlas_core.rmvp_04_success(
    jsonb, uuid, uuid, text, uuid, bigint, bigint, text, jsonb, jsonb, uuid
  ),
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(
    jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint
  ),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(
    jsonb, uuid, text, text, text, uuid, uuid, uuid
  ),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean)
to atlas_need_generation_runtime;

grant atlas_need_generation_runtime to postgres with set true;
grant create on schema atlas_core, atlas_api to atlas_need_generation_runtime;
alter function atlas_core.rmvp_04_safe_date(text)
  owner to atlas_need_generation_runtime;
alter function atlas_core.rmvp_04_error(
  jsonb, text, text, text, boolean, boolean, jsonb, jsonb, bigint
) owner to atlas_need_generation_runtime;
alter function atlas_core.rmvp_04_authorize_global(jsonb, text, text, boolean)
  owner to atlas_need_generation_runtime;
alter function atlas_core.rmvp_04_validate_read(jsonb, text)
  owner to atlas_need_generation_runtime;
alter function atlas_core.rmvp_04_validate_command(jsonb, text)
  owner to atlas_need_generation_runtime;
alter function atlas_core.rmvp_04_prepare_command(jsonb, text, text)
  owner to atlas_need_generation_runtime;
alter function atlas_core.rmvp_04_record_change(
  jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb
) owner to atlas_need_generation_runtime;
alter function atlas_core.rmvp_04_workbench_payload(
  date, date, uuid, jsonb, integer, integer, jsonb
) owner to atlas_need_generation_runtime;
alter function atlas_core.rmvp_04_success(
  jsonb, uuid, uuid, text, uuid, bigint, bigint, text, jsonb, jsonb, uuid
) owner to atlas_need_generation_runtime;
alter function atlas_api.get_need_generation_workbench(jsonb)
  owner to atlas_need_generation_runtime;
alter function atlas_api.create_need_generation_run(jsonb)
  owner to atlas_need_generation_runtime;
alter function atlas_api.validate_need_generation_run(jsonb)
  owner to atlas_need_generation_runtime;
alter function atlas_api.release_need_generation_run(jsonb)
  owner to atlas_need_generation_runtime;
alter function atlas_api.invalidate_need_generation_run(jsonb)
  owner to atlas_need_generation_runtime;
revoke create on schema atlas_core, atlas_api from atlas_need_generation_runtime;

revoke execute on function
  atlas_api.get_need_generation_workbench(jsonb),
  atlas_api.create_need_generation_run(jsonb),
  atlas_api.validate_need_generation_run(jsonb),
  atlas_api.release_need_generation_run(jsonb),
  atlas_api.invalidate_need_generation_run(jsonb)
from public, anon, authenticated, service_role;

grant execute on function
  atlas_api.get_need_generation_workbench(jsonb),
  atlas_api.create_need_generation_run(jsonb),
  atlas_api.validate_need_generation_run(jsonb),
  atlas_api.release_need_generation_run(jsonb),
  atlas_api.invalidate_need_generation_run(jsonb)
to authenticated;

comment on function atlas_api.get_need_generation_workbench(jsonb) is
  'RMVP-04 authorized exact-period readiness, immutable run, grouped demand, detail, history, action, and Confirmed Need read.';
comment on function atlas_api.create_need_generation_run(jsonb) is
  'RMVP-04 atomic generation from exact current Menu, Attendance, Pantry, Recipe, and calculation-contract evidence.';
comment on function atlas_api.validate_need_generation_run(jsonb) is
  'RMVP-04 blocker-free terminal GENERATED to VALIDATED transition.';
comment on function atlas_api.release_need_generation_run(jsonb) is
  'RMVP-04 immutable every-and-only release membership and VALIDATED to RELEASED_FOR_CONFIRMATION transition.';
comment on function atlas_api.invalidate_need_generation_run(jsonb) is
  'RMVP-04 reasoned terminal invalidation with downstream correction safety.';

-- RMVP-03B write APIs are fixed-search-path security definers owned by the
-- bounded Planning command runtime, but their H0A4B integrity trigger is
-- deferred. PostgREST commits after the API function returns, when the browser
-- role is current again and intentionally has no private-schema usage. Flush
-- the invariant before a successful response while the bounded runtime remains
-- current, then restore deferred mode for callers that own a wider transaction.
set role atlas_owner;

create or replace function atlas_core.rmvp_03b_finish_success(
  request jsonb,
  actor_id uuid,
  receipt_id uuid,
  event_type text,
  input_set_id uuid,
  evaluation_id uuid,
  evaluation_version bigint,
  before_summary jsonb,
  after_summary jsonb,
  safe_message text,
  source_selection jsonb default null
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_events jsonb;
  v_response jsonb;
  v_set atlas_planning.planning_input_sets%rowtype;
  v_readback jsonb;
begin
  set constraints all immediate;
  set constraints all deferred;

  v_events := atlas_core.rmvp_03b_record_change(
    request, actor_id, receipt_id, event_type, input_set_id,
    before_summary, after_summary
  );
  select * into v_set from atlas_planning.planning_input_sets input_set
  where input_set.planning_input_set_id = input_set_id;
  v_readback := atlas_core.rmvp_03b_workbench_payload(
    v_set.period_start, v_set.period_end, source_selection, 25, null
  );
  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-03B.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'planning_input_set_id', input_set_id,
      'planning_input_evaluation_id', evaluation_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'current_evaluation_version', evaluation_version
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'audit_event_id'
    ),
    'safe_operator_message', safe_message,
    'warnings', coalesce(
      v_readback -> 'current_evaluation' -> 'issues' -> 'warnings',
      '[]'::jsonb
    ),
    'blockers', coalesce(
      v_readback -> 'current_evaluation' -> 'issues' -> 'blockers',
      '[]'::jsonb
    ),
    'authoritative_readback', v_readback
  );
  return atlas_core.pa_05b_finish_command(receipt_id, v_response, true);
end;
$$;

reset role;

-- CMD-15 has the same PostgREST boundary: its Confirmed Need invariants are
-- deferred until transaction end. Preserve the exact reviewed function body
-- and contract while inserting one fail-closed success-boundary flush before
-- the function returns to the browser role. The exact anchor makes migration
-- drift fail instead of silently rewriting an unexpected command definition.
grant atlas_planning_materialization_runtime to postgres with set true;
grant create on schema atlas_api to atlas_planning_materialization_runtime;
set role atlas_planning_materialization_runtime;

do $migration$
declare
  function_definition text;
  success_anchor constant text := E'  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);\nexception';
  success_replacement constant text := E'  set constraints all immediate;\n  set constraints all deferred;\n  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);\nexception';
  anchor_count integer;
begin
  select pg_catalog.pg_get_functiondef(
    'atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure
  ) into function_definition;

  anchor_count := (
    pg_catalog.length(function_definition)
    - pg_catalog.length(pg_catalog.replace(function_definition, success_anchor, ''))
  ) / pg_catalog.length(success_anchor);

  if anchor_count <> 1 then
    raise exception using
      errcode = '55000',
      message = 'CMD-15 success-boundary anchor must occur exactly once';
  end if;

  execute pg_catalog.replace(
    function_definition,
    success_anchor,
    success_replacement
  );
end
$migration$;

reset role;
revoke create on schema atlas_api from atlas_planning_materialization_runtime;
revoke atlas_planning_materialization_runtime from postgres;

revoke atlas_need_generation_runtime from postgres;
