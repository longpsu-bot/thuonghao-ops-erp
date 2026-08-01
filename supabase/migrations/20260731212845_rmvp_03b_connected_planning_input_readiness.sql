-- RMVP-03B: connected Planning Input Readiness.
--
-- This migration exposes the existing three-source readiness persistence
-- through one shaped read and three transactional commands. It deliberately
-- creates no relation, view, runtime role, lifecycle state, source trigger,
-- Need Generation run, or downstream operational fact.

set role atlas_owner;

reset role;

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values (
  'planning.input_readiness.write',
  'Evaluate and control Planning Input Readiness',
  'PLANNING',
  'ACTIVE'
);

set role atlas_owner;

create function atlas_core.rmvp_03b_safe_date(value text)
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

create function atlas_core.rmvp_03b_normalize_text(value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(
    pg_catalog.normalize(pg_catalog.btrim(coalesce(value, '')), 'NFC'),
    ''
  );
$$;

create function atlas_core.rmvp_03b_sha256(value jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $$
begin
  return pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(coalesce(value, 'null'::jsonb)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
end;
$$;

create function atlas_core.rmvp_03b_error(
  request jsonb,
  operation_name text,
  error_code text,
  safe_message text,
  is_read boolean default false,
  retryable boolean default false,
  field_errors jsonb default '[]'::jsonb,
  blocking_references jsonb default '[]'::jsonb,
  actual_status text default null,
  actual_evaluation_id uuid default null,
  actual_evaluation_version bigint default null
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RMVP-03B.v1',
      'error_code', error_code,
      'safe_message', safe_message,
      'domain', 'PLANNING',
      case when is_read then 'read_name' else 'command_name' end,
        operation_name,
      'retryable', retryable,
      'field_errors', coalesce(field_errors, '[]'::jsonb),
      'blocking_references',
        coalesce(blocking_references, '[]'::jsonb),
      'expected_root_status', request ->> 'expected_root_status',
      'expected_current_evaluation_id',
        request ->> 'expected_current_evaluation_id',
      'expected_current_evaluation_version',
        request ->> 'expected_current_evaluation_version',
      'actual_root_status', actual_status,
      'actual_current_evaluation_id', actual_evaluation_id,
      'actual_current_evaluation_version', actual_evaluation_version,
      'correlation_id', request ->> 'correlation_id',
      'command_id', case when is_read then null else request ->> 'command_id' end
    )
  );
$$;

create function atlas_core.rmvp_03b_authorize_global(
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
    v_error := v_context -> 'error';
    return pg_catalog.jsonb_build_object(
      'error',
      v_error || pg_catalog.jsonb_build_object(
        'contract_version', 'RMVP-03B.v1',
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
        'contract_version', 'RMVP-03B.v1',
        case when is_read then 'read_name' else 'command_name' end,
          operation_name
      )
    );
  end if;
  return pg_catalog.jsonb_build_object('actor_id', v_actor_id);
end;
$$;

create function atlas_core.rmvp_03b_validate_read(
  request jsonb,
  read_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
  v_start date;
  v_end date;
  v_limit bigint;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_03b_error(
      coalesce(request, '{}'::jsonb), read_name, 'VALIDATION_FAILED',
      'The read request must be a JSON object.', true
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-03B.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version', 'message', 'Use RMVP-03B.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
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
    v_start := atlas_core.rmvp_03b_safe_date(
      request -> 'payload' ->> 'period_start'
    );
    v_end := atlas_core.rmvp_03b_safe_date(
      request -> 'payload' ->> 'period_end'
    );
    if v_start is null or v_end is null or v_end < v_start then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.period',
          'message', 'A valid inclusive period is required.'
        )
      );
    end if;
    if request -> 'payload' ? 'source_selection'
      and pg_catalog.jsonb_typeof(
        request -> 'payload' -> 'source_selection'
      ) is distinct from 'object'
    then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.source_selection',
          'message', 'Source selection must be an object.'
        )
      );
    end if;
    if request -> 'payload' ? 'history_limit' then
      v_limit := atlas_core.pa_05b_safe_bigint(
        request -> 'payload' ->> 'history_limit'
      );
      if v_limit is null or v_limit < 1 or v_limit > 50 then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'field', 'payload.history_limit',
            'message', 'History limit must be between 1 and 50.'
          )
        );
      end if;
    end if;
    if request -> 'payload' ? 'history_cursor'
      and request -> 'payload' -> 'history_cursor' <> 'null'::jsonb
      and (
        pg_catalog.jsonb_typeof(
          request -> 'payload' -> 'history_cursor'
        ) <> 'string'
        or pg_catalog.btrim(
          request -> 'payload' ->> 'history_cursor'
        ) = ''
      )
    then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.history_cursor',
          'message', 'History cursor must be an opaque nonblank string.'
        )
      );
    end if;
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_03b_error(
      request, read_name, 'VALIDATION_FAILED',
      'The readiness read envelope is invalid.', true, false, v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_core.rmvp_03b_validate_command(
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
  v_requested_at timestamptz;
  v_start date;
  v_end date;
  v_expected_status text;
  v_expected_id uuid;
  v_expected_version bigint;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_03b_error(
      coalesce(request, '{}'::jsonb), command_name, 'VALIDATION_FAILED',
      'The command request must be a JSON object.'
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-03B.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version', 'message', 'Use RMVP-03B.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'command_id', 'message', 'A valid UUID is required.'
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
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
    or pg_catalog.length(request ->> 'idempotency_key') > 200
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'idempotency_key',
        'message', 'A nonblank key of at most 200 characters is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
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
        'field', 'requested_at',
        'message', 'A valid non-future timestamp is required.'
      )
    );
  end if;
  v_expected_status := request ->> 'expected_root_status';
  v_expected_id := atlas_core.pa_05b_safe_uuid(
    request ->> 'expected_current_evaluation_id'
  );
  v_expected_version := atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_current_evaluation_version'
  );
  if v_expected_status not in (
    'ABSENT', 'NOT_READY', 'READY',
    'NEED_GENERATION_REQUESTED', 'INVALIDATED'
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_root_status',
        'message', 'A valid expected root status is required.'
      )
    );
  elsif v_expected_status = 'ABSENT' and (
    request -> 'expected_current_evaluation_id' <> 'null'::jsonb
    or request -> 'expected_current_evaluation_version' <> 'null'::jsonb
    or not (request ? 'expected_current_evaluation_id')
    or not (request ? 'expected_current_evaluation_version')
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_current_evaluation',
        'message', 'ABSENT requires null evaluation expectations.'
      )
    );
  elsif v_expected_status <> 'ABSENT'
    and (v_expected_id is null or v_expected_version is null
      or v_expected_version < 1)
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_current_evaluation',
        'message', 'Existing roots require exact evaluation expectations.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = ''
    or not (request ? 'reason_note')
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason',
        'message', 'A reason code and explicit nullable note are required.'
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
    v_start := atlas_core.rmvp_03b_safe_date(
      request -> 'payload' ->> 'period_start'
    );
    v_end := atlas_core.rmvp_03b_safe_date(
      request -> 'payload' ->> 'period_end'
    );
    if v_start is null or v_end is null or v_end < v_start then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.period',
          'message', 'A valid inclusive period is required.'
        )
      );
    end if;
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_03b_error(
      request, command_name, 'VALIDATION_FAILED',
      'The readiness command envelope is invalid.', false, false, v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_core.rmvp_03b_candidate_is_well_formed(
  source_kind text,
  candidate jsonb
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case source_kind
    when 'WEEKLY_MENU' then
      pg_catalog.jsonb_typeof(candidate) = 'object'
      and (select count(*) from pg_catalog.jsonb_object_keys(candidate)) = 3
      and atlas_core.pa_05b_safe_uuid(candidate ->> 'weekly_menu_id')
        is not null
      and atlas_core.pa_05b_safe_bigint(
        candidate ->> 'weekly_menu_version'
      ) > 0
      and atlas_core.pa_05b_safe_uuid(
        candidate ->> 'weekly_menu_approval_snapshot_id'
      ) is not null
    when 'ATTENDANCE' then
      pg_catalog.jsonb_typeof(candidate) = 'object'
      and (select count(*) from pg_catalog.jsonb_object_keys(candidate)) = 3
      and atlas_core.pa_05b_safe_uuid(candidate ->> 'attendance_batch_id')
        is not null
      and atlas_core.pa_05b_safe_bigint(
        candidate ->> 'attendance_version'
      ) > 0
      and atlas_core.pa_05b_safe_uuid(
        candidate ->> 'attendance_approval_snapshot_id'
      ) is not null
    when 'PANTRY' then
      pg_catalog.jsonb_typeof(candidate) = 'object'
      and (select count(*) from pg_catalog.jsonb_object_keys(candidate)) = 3
      and atlas_core.pa_05b_safe_uuid(candidate ->> 'pantry_need_batch_id')
        is not null
      and atlas_core.pa_05b_safe_bigint(
        candidate ->> 'pantry_need_batch_version'
      ) > 0
      and atlas_core.pa_05b_safe_uuid(
        candidate ->> 'pantry_need_approval_snapshot_id'
      ) is not null
    else false
  end;
$$;

create function atlas_core.rmvp_03b_source_evidence(
  source_kind text,
  p_period_start date,
  p_period_end date,
  supplied jsonb default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_candidates jsonb := '[]'::jsonb;
  v_count integer := 0;
  v_selected jsonb;
  v_historical jsonb;
  v_state text;
  v_coverage text := 'NOT_APPLICABLE';
  v_current boolean;
  v_error text;
begin
  if supplied is not null
    and not atlas_core.rmvp_03b_candidate_is_well_formed(
      source_kind, supplied
    )
  then
    return pg_catalog.jsonb_build_object(
      'validation_error', 'MALFORMED_SOURCE_SELECTION'
    );
  end if;

  if source_kind = 'WEEKLY_MENU' then
    select coalesce(pg_catalog.jsonb_agg(candidate order by
      candidate -> 'source_period' ->> 'period_start',
      candidate ->> 'weekly_menu_id',
      candidate ->> 'weekly_menu_approval_snapshot_id'), '[]'::jsonb)
    into v_candidates
    from (
      select pg_catalog.jsonb_build_object(
        'weekly_menu_id', menu.weekly_menu_id,
        'weekly_menu_version', menu.version,
        'weekly_menu_approval_snapshot_id', snapshot.weekly_menu_approval_snapshot_id,
        'source_period', pg_catalog.jsonb_build_object(
          'period_start', menu.week_start,
          'period_end', menu.week_end
        ),
        'source_status', menu.weekly_menu_status,
        'latest_approval', true,
        'source_current', true,
        'approved_by_actor_id', snapshot.approved_by_actor_id,
        'approved_by_display_name', actor.display_name,
        'approved_at', snapshot.approved_at,
        'line_count', (
          select count(*) from atlas_planning.weekly_menu_approval_snapshot_lines line
          where line.weekly_menu_approval_snapshot_id = snapshot.weekly_menu_approval_snapshot_id
        ),
        'coverage', case when menu.week_start <= p_period_start
          and menu.week_end >= p_period_end then 'COVERS'
          else 'DOES_NOT_COVER' end
      ) as candidate
      from atlas_planning.weekly_menus menu
      join atlas_planning.weekly_menu_approval_snapshots snapshot
        on snapshot.weekly_menu_approval_snapshot_id = menu.latest_approval_snapshot_id
       and snapshot.weekly_menu_id = menu.weekly_menu_id
       and snapshot.weekly_menu_version = menu.version
      join atlas_core.actors actor on actor.actor_id = snapshot.approved_by_actor_id
      where menu.weekly_menu_status in ('APPROVED', 'NEED_GENERATION_REQUESTED')
        and menu.week_start <= p_period_end and menu.week_end >= p_period_start
    ) candidates;
    if supplied is not null then
      select candidate into v_selected
      from pg_catalog.jsonb_array_elements(v_candidates) candidate
      where candidate ->> 'weekly_menu_id' = supplied ->> 'weekly_menu_id'
        and candidate ->> 'weekly_menu_version' = supplied ->> 'weekly_menu_version'
        and candidate ->> 'weekly_menu_approval_snapshot_id' = supplied ->> 'weekly_menu_approval_snapshot_id';
      if v_selected is null then
        select pg_catalog.jsonb_build_object(
          'weekly_menu_id', menu.weekly_menu_id,
          'weekly_menu_version', snapshot.weekly_menu_version,
          'weekly_menu_approval_snapshot_id', snapshot.weekly_menu_approval_snapshot_id,
          'source_period', pg_catalog.jsonb_build_object('period_start', menu.week_start, 'period_end', menu.week_end),
          'source_status', menu.weekly_menu_status,
          'latest_approval', menu.latest_approval_snapshot_id = snapshot.weekly_menu_approval_snapshot_id and menu.version = snapshot.weekly_menu_version,
          'source_current', false,
          'approved_by_actor_id', snapshot.approved_by_actor_id,
          'approved_by_display_name', actor.display_name,
          'approved_at', snapshot.approved_at,
          'line_count', (select count(*) from atlas_planning.weekly_menu_approval_snapshot_lines line where line.weekly_menu_approval_snapshot_id = snapshot.weekly_menu_approval_snapshot_id),
          'coverage', case when menu.week_start <= p_period_start and menu.week_end >= p_period_end then 'COVERS' else 'DOES_NOT_COVER' end
        ) into v_historical
        from atlas_planning.weekly_menu_approval_snapshots snapshot
        join atlas_planning.weekly_menus menu on menu.weekly_menu_id = snapshot.weekly_menu_id
        join atlas_core.actors actor on actor.actor_id = snapshot.approved_by_actor_id
        where snapshot.weekly_menu_id = atlas_core.pa_05b_safe_uuid(supplied ->> 'weekly_menu_id')
          and snapshot.weekly_menu_version = atlas_core.pa_05b_safe_bigint(supplied ->> 'weekly_menu_version')
          and snapshot.weekly_menu_approval_snapshot_id = atlas_core.pa_05b_safe_uuid(supplied ->> 'weekly_menu_approval_snapshot_id');
      end if;
    end if;
  elsif source_kind = 'ATTENDANCE' then
    select coalesce(pg_catalog.jsonb_agg(candidate order by
      candidate -> 'source_period' ->> 'period_start',
      candidate ->> 'attendance_batch_id',
      candidate ->> 'attendance_approval_snapshot_id'), '[]'::jsonb)
    into v_candidates
    from (
      select pg_catalog.jsonb_build_object(
        'attendance_batch_id', batch.attendance_batch_id,
        'attendance_version', batch.version,
        'attendance_approval_snapshot_id', snapshot.attendance_approval_snapshot_id,
        'source_period', pg_catalog.jsonb_build_object('period_start', batch.period_start, 'period_end', batch.period_end),
        'source_status', batch.attendance_status,
        'latest_approval', true,
        'source_current', true,
        'approved_by_actor_id', snapshot.approved_by_actor_id,
        'approved_by_display_name', actor.display_name,
        'approved_at', snapshot.approved_at,
        'line_count', (select count(*) from atlas_planning.attendance_approval_snapshot_lines line where line.attendance_approval_snapshot_id = snapshot.attendance_approval_snapshot_id),
        'coverage', case when batch.period_start <= p_period_start and batch.period_end >= p_period_end then 'COVERS' else 'DOES_NOT_COVER' end
      ) as candidate
      from atlas_planning.attendance_batches batch
      join atlas_planning.attendance_approval_snapshots snapshot
        on snapshot.attendance_approval_snapshot_id = batch.latest_approval_snapshot_id
       and snapshot.attendance_batch_id = batch.attendance_batch_id
       and snapshot.attendance_version = batch.version
      join atlas_core.actors actor on actor.actor_id = snapshot.approved_by_actor_id
      where batch.attendance_status in ('APPROVED', 'USED_FOR_NEED_GENERATION')
        and batch.period_start <= p_period_end and batch.period_end >= p_period_start
    ) candidates;
    if supplied is not null then
      select candidate into v_selected
      from pg_catalog.jsonb_array_elements(v_candidates) candidate
      where candidate ->> 'attendance_batch_id' = supplied ->> 'attendance_batch_id'
        and candidate ->> 'attendance_version' = supplied ->> 'attendance_version'
        and candidate ->> 'attendance_approval_snapshot_id' = supplied ->> 'attendance_approval_snapshot_id';
      if v_selected is null then
        select pg_catalog.jsonb_build_object(
          'attendance_batch_id', batch.attendance_batch_id,
          'attendance_version', snapshot.attendance_version,
          'attendance_approval_snapshot_id', snapshot.attendance_approval_snapshot_id,
          'source_period', pg_catalog.jsonb_build_object('period_start', batch.period_start, 'period_end', batch.period_end),
          'source_status', batch.attendance_status,
          'latest_approval', batch.latest_approval_snapshot_id = snapshot.attendance_approval_snapshot_id and batch.version = snapshot.attendance_version,
          'source_current', false,
          'approved_by_actor_id', snapshot.approved_by_actor_id,
          'approved_by_display_name', actor.display_name,
          'approved_at', snapshot.approved_at,
          'line_count', (select count(*) from atlas_planning.attendance_approval_snapshot_lines line where line.attendance_approval_snapshot_id = snapshot.attendance_approval_snapshot_id),
          'coverage', case when batch.period_start <= p_period_start and batch.period_end >= p_period_end then 'COVERS' else 'DOES_NOT_COVER' end
        ) into v_historical
        from atlas_planning.attendance_approval_snapshots snapshot
        join atlas_planning.attendance_batches batch on batch.attendance_batch_id = snapshot.attendance_batch_id
        join atlas_core.actors actor on actor.actor_id = snapshot.approved_by_actor_id
        where snapshot.attendance_batch_id = atlas_core.pa_05b_safe_uuid(supplied ->> 'attendance_batch_id')
          and snapshot.attendance_version = atlas_core.pa_05b_safe_bigint(supplied ->> 'attendance_version')
          and snapshot.attendance_approval_snapshot_id = atlas_core.pa_05b_safe_uuid(supplied ->> 'attendance_approval_snapshot_id');
      end if;
    end if;
  elsif source_kind = 'PANTRY' then
    select coalesce(pg_catalog.jsonb_agg(candidate order by
      candidate -> 'source_period' ->> 'period_start',
      candidate ->> 'pantry_need_batch_id',
      candidate ->> 'pantry_need_approval_snapshot_id'), '[]'::jsonb)
    into v_candidates
    from (
      select pg_catalog.jsonb_build_object(
        'pantry_need_batch_id', batch.pantry_need_batch_id,
        'pantry_need_batch_version', batch.version,
        'pantry_need_approval_snapshot_id', snapshot.pantry_need_approval_snapshot_id,
        'source_period', pg_catalog.jsonb_build_object('period_start', batch.week_start, 'period_end', batch.week_end),
        'source_status', batch.pantry_need_batch_status,
        'latest_approval', true,
        'source_current', true,
        'approved_by_actor_id', snapshot.approved_by_actor_id,
        'approved_by_display_name', actor.display_name,
        'approved_at', snapshot.approved_at,
        'line_count', snapshot.line_count,
        'no_additions_confirmed', snapshot.no_additions_confirmed,
        'pantry_evidence_kind', case when snapshot.line_count = 0 then 'EXPLICIT_ZERO_LINES' else 'POSITIVE_LINES' end,
        'coverage', case when batch.week_start <= p_period_start and batch.week_end >= p_period_end then 'COVERS' else 'DOES_NOT_COVER' end
      ) as candidate
      from atlas_planning.pantry_need_batches batch
      join atlas_planning.pantry_need_approval_snapshots snapshot
        on snapshot.pantry_need_approval_snapshot_id = batch.latest_approval_snapshot_id
       and snapshot.pantry_need_batch_id = batch.pantry_need_batch_id
       and snapshot.approved_batch_version = batch.version
      join atlas_core.actors actor on actor.actor_id = snapshot.approved_by_actor_id
      where batch.pantry_need_batch_status = 'APPROVED'
        and batch.week_start <= p_period_end and batch.week_end >= p_period_start
        and snapshot.line_count = (select count(*) from atlas_planning.pantry_need_approval_snapshot_lines line where line.pantry_need_approval_snapshot_id = snapshot.pantry_need_approval_snapshot_id)
        and (snapshot.line_count > 0 or snapshot.no_additions_confirmed)
    ) candidates;
    if supplied is not null then
      select candidate into v_selected
      from pg_catalog.jsonb_array_elements(v_candidates) candidate
      where candidate ->> 'pantry_need_batch_id' = supplied ->> 'pantry_need_batch_id'
        and candidate ->> 'pantry_need_batch_version' = supplied ->> 'pantry_need_batch_version'
        and candidate ->> 'pantry_need_approval_snapshot_id' = supplied ->> 'pantry_need_approval_snapshot_id';
      if v_selected is null then
        select pg_catalog.jsonb_build_object(
          'pantry_need_batch_id', batch.pantry_need_batch_id,
          'pantry_need_batch_version', snapshot.approved_batch_version,
          'pantry_need_approval_snapshot_id', snapshot.pantry_need_approval_snapshot_id,
          'source_period', pg_catalog.jsonb_build_object('period_start', batch.week_start, 'period_end', batch.week_end),
          'source_status', batch.pantry_need_batch_status,
          'latest_approval', batch.latest_approval_snapshot_id = snapshot.pantry_need_approval_snapshot_id and batch.version = snapshot.approved_batch_version,
          'source_current', false,
          'approved_by_actor_id', snapshot.approved_by_actor_id,
          'approved_by_display_name', actor.display_name,
          'approved_at', snapshot.approved_at,
          'line_count', snapshot.line_count,
          'no_additions_confirmed', snapshot.no_additions_confirmed,
          'pantry_evidence_kind', case when snapshot.line_count = 0 and snapshot.no_additions_confirmed then 'EXPLICIT_ZERO_LINES' when snapshot.line_count > 0 then 'POSITIVE_LINES' else 'INVALID_ZERO_EVIDENCE' end,
          'coverage', case when batch.week_start <= p_period_start and batch.week_end >= p_period_end then 'COVERS' else 'DOES_NOT_COVER' end
        ) into v_historical
        from atlas_planning.pantry_need_approval_snapshots snapshot
        join atlas_planning.pantry_need_batches batch on batch.pantry_need_batch_id = snapshot.pantry_need_batch_id
        join atlas_core.actors actor on actor.actor_id = snapshot.approved_by_actor_id
        where snapshot.pantry_need_batch_id = atlas_core.pa_05b_safe_uuid(supplied ->> 'pantry_need_batch_id')
          and snapshot.approved_batch_version = atlas_core.pa_05b_safe_bigint(supplied ->> 'pantry_need_batch_version')
          and snapshot.pantry_need_approval_snapshot_id = atlas_core.pa_05b_safe_uuid(supplied ->> 'pantry_need_approval_snapshot_id');
      end if;
    end if;
  else
    return pg_catalog.jsonb_build_object('validation_error', 'INVALID_SOURCE_KIND');
  end if;

  v_count := pg_catalog.jsonb_array_length(v_candidates);
  if supplied is not null and v_selected is not null then
    v_state := 'SELECTED';
    v_current := true;
  elsif supplied is not null and v_historical is null then
    v_error := 'SOURCE_CANDIDATE_OWNERSHIP_MISMATCH';
  elsif supplied is not null and (
    atlas_core.rmvp_03b_safe_date(v_historical -> 'source_period' ->> 'period_start') > p_period_end
    or atlas_core.rmvp_03b_safe_date(v_historical -> 'source_period' ->> 'period_end') < p_period_start
  ) then
    v_error := 'FOREIGN_PERIOD_SOURCE_SELECTION';
  elsif supplied is not null then
    v_state := 'STALE';
    v_selected := v_historical;
    v_current := false;
  elsif v_count = 0 then
    v_state := 'MISSING';
    v_current := false;
  elsif v_count = 1 then
    v_state := 'SELECTED';
    v_selected := v_candidates -> 0;
    v_current := true;
  else
    v_state := 'AMBIGUOUS';
    v_current := false;
  end if;
  if v_error is not null then
    return pg_catalog.jsonb_build_object('validation_error', v_error);
  end if;
  if v_selected is not null then
    v_coverage := v_selected ->> 'coverage';
  end if;
  return pg_catalog.jsonb_build_object(
    'selection_state', v_state,
    'coverage', v_coverage,
    'source_current', v_current,
    'selected', v_selected,
    'candidates', v_candidates,
    'pantry_evidence_kind', case
      when source_kind = 'PANTRY' and v_state = 'MISSING' then 'MISSING'
      when source_kind = 'PANTRY' and v_selected is not null
        then v_selected ->> 'pantry_evidence_kind'
      else null end,
    'safe_message', case v_state
      when 'SELECTED' then 'Current approved source evidence is selected.'
      when 'MISSING' then 'No current approved overlapping source exists.'
      when 'AMBIGUOUS' then 'Choose one current approved overlapping source.'
      else 'The previously selected source is no longer current.' end
  );
end;
$$;

create function atlas_core.rmvp_03b_calculate_issues(
  period_start date,
  period_end date,
  weekly_evidence jsonb,
  attendance_evidence jsonb,
  pantry_evidence jsonb
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with blocker_issues as (
    select
      'BLOCKING'::text as severity,
      'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT'::text as issue_code,
      'No current approved Weekly Menu overlaps the evaluated period.'::text
        as message,
      'WEEKLY_MENU'::text as input_type,
      null::uuid as school_id,
      null::date as service_date
    where weekly_evidence ->> 'selection_state' = 'MISSING'
    union all
    select 'BLOCKING', 'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT',
      'No current approved Attendance batch overlaps the evaluated period.',
      'ATTENDANCE', null::uuid, null::date
    where attendance_evidence ->> 'selection_state' = 'MISSING'
    union all
    select 'BLOCKING', 'MISSING_PANTRY_APPROVAL_SNAPSHOT',
      'No current approved Pantry batch overlaps the evaluated period.',
      'PANTRY', null::uuid, null::date
    where pantry_evidence ->> 'selection_state' = 'MISSING'
    union all
    select 'BLOCKING',
      'WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'The selected Weekly Menu does not cover the complete evaluated period.',
      'WEEKLY_MENU', null::uuid, null::date
    where weekly_evidence ->> 'selection_state' = 'SELECTED'
      and weekly_evidence ->> 'coverage' = 'DOES_NOT_COVER'
    union all
    select 'BLOCKING',
      'ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'The selected Attendance batch does not cover the complete evaluated period.',
      'ATTENDANCE', null::uuid, null::date
    where attendance_evidence ->> 'selection_state' = 'SELECTED'
      and attendance_evidence ->> 'coverage' = 'DOES_NOT_COVER'
    union all
    select 'BLOCKING',
      'PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'The selected Pantry batch does not cover the complete evaluated period.',
      'PANTRY', null::uuid, null::date
    where pantry_evidence ->> 'selection_state' = 'SELECTED'
      and pantry_evidence ->> 'coverage' = 'DOES_NOT_COVER'
  ), menu_days as (
    select distinct line.school_id, line.service_date
    from atlas_planning.weekly_menu_approval_snapshot_lines line
    where line.weekly_menu_approval_snapshot_id = atlas_core.pa_05b_safe_uuid(
      weekly_evidence -> 'selected' ->> 'weekly_menu_approval_snapshot_id'
    )
      and line.service_date between period_start and period_end
  ), attendance_days as (
    select line.school_id, line.service_date,
      line.student_portions + line.teacher_portions as total_portions
    from atlas_planning.attendance_approval_snapshot_lines line
    where line.attendance_approval_snapshot_id = atlas_core.pa_05b_safe_uuid(
      attendance_evidence -> 'selected' ->> 'attendance_approval_snapshot_id'
    )
      and line.service_date between period_start and period_end
  ), warning_issues as (
    select
      'WARNING'::text as severity,
      'MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE'::text as issue_code,
      'A planned menu School/date has no Attendance row.'::text as message,
      'ATTENDANCE'::text as input_type,
      menu.school_id,
      menu.service_date
    from menu_days menu
    where not exists (
      select 1 from attendance_days attendance
      where attendance.school_id = menu.school_id
        and attendance.service_date = menu.service_date
    )
    union all
    select 'WARNING', 'ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU',
      'An Attendance School/date has no planned menu.',
      'WEEKLY_MENU', attendance.school_id, attendance.service_date
    from attendance_days attendance
    where not exists (
      select 1 from menu_days menu
      where menu.school_id = attendance.school_id
        and menu.service_date = attendance.service_date
    )
    union all
    select 'WARNING', 'ZERO_ATTENDANCE_FOR_PLANNED_MENU',
      'A planned menu School/date has zero Attendance.',
      'ATTENDANCE', attendance.school_id, attendance.service_date
    from attendance_days attendance
    where attendance.total_portions = 0
      and exists (
        select 1 from menu_days menu
        where menu.school_id = attendance.school_id
          and menu.service_date = attendance.service_date
      )
  ), issues as (
    select * from blocker_issues
    union all
    select * from warning_issues
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'severity', severity,
        'issue_code', issue_code,
        'message', message,
        'input_type', input_type,
        'school_id', school_id,
        'service_date', service_date
      )
      order by case severity when 'BLOCKING' then 1 else 2 end,
        issue_code, school_id, service_date
    ),
    '[]'::jsonb
  )
  from issues;
$$;

create function atlas_core.rmvp_03b_bindings_current(
  evaluation_id uuid,
  period_start date,
  period_end date
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_planning.planning_input_evaluations evaluation
    join atlas_planning.weekly_menus menu
      on menu.weekly_menu_id = evaluation.weekly_menu_id
    join atlas_planning.attendance_batches attendance
      on attendance.attendance_batch_id = evaluation.attendance_batch_id
    join atlas_planning.pantry_need_batches pantry
      on pantry.pantry_need_batch_id = evaluation.pantry_need_batch_id
    where evaluation.planning_input_evaluation_id = evaluation_id
      and evaluation.weekly_menu_id is not null
      and evaluation.attendance_batch_id is not null
      and evaluation.pantry_need_batch_id is not null
      and menu.version = evaluation.weekly_menu_version
      and menu.latest_approval_snapshot_id =
        evaluation.weekly_menu_approval_snapshot_id
      and menu.weekly_menu_status in ('APPROVED', 'NEED_GENERATION_REQUESTED')
      and menu.week_start <= period_start and menu.week_end >= period_end
      and attendance.version = evaluation.attendance_version
      and attendance.latest_approval_snapshot_id =
        evaluation.attendance_approval_snapshot_id
      and attendance.attendance_status in ('APPROVED', 'USED_FOR_NEED_GENERATION')
      and attendance.period_start <= period_start
      and attendance.period_end >= period_end
      and pantry.version = evaluation.pantry_need_batch_version
      and pantry.latest_approval_snapshot_id =
        evaluation.pantry_need_approval_snapshot_id
      and pantry.pantry_need_batch_status = 'APPROVED'
      and pantry.week_start <= period_start and pantry.week_end >= period_end
  );
$$;

create function atlas_core.rmvp_03b_stale_source_types(
  evaluation_id uuid,
  period_start date,
  period_end date
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with evaluation as (
    select * from atlas_planning.planning_input_evaluations
    where planning_input_evaluation_id = evaluation_id
  ), stale as (
    select 'WEEKLY_MENU'::text as source_type
    from evaluation
    where weekly_menu_id is null or not exists (
      select 1 from atlas_planning.weekly_menus menu
      where menu.weekly_menu_id = evaluation.weekly_menu_id
        and menu.version = evaluation.weekly_menu_version
        and menu.latest_approval_snapshot_id = evaluation.weekly_menu_approval_snapshot_id
        and menu.weekly_menu_status in ('APPROVED', 'NEED_GENERATION_REQUESTED')
        and menu.week_start <= period_start and menu.week_end >= period_end
    )
    union all
    select 'ATTENDANCE' from evaluation
    where attendance_batch_id is null or not exists (
      select 1 from atlas_planning.attendance_batches batch
      where batch.attendance_batch_id = evaluation.attendance_batch_id
        and batch.version = evaluation.attendance_version
        and batch.latest_approval_snapshot_id = evaluation.attendance_approval_snapshot_id
        and batch.attendance_status in ('APPROVED', 'USED_FOR_NEED_GENERATION')
        and batch.period_start <= period_start and batch.period_end >= period_end
    )
    union all
    select 'PANTRY' from evaluation
    where pantry_need_batch_id is null or not exists (
      select 1 from atlas_planning.pantry_need_batches batch
      where batch.pantry_need_batch_id = evaluation.pantry_need_batch_id
        and batch.version = evaluation.pantry_need_batch_version
        and batch.latest_approval_snapshot_id = evaluation.pantry_need_approval_snapshot_id
        and batch.pantry_need_batch_status = 'APPROVED'
        and batch.week_start <= period_start and batch.week_end >= period_end
    )
  )
  select coalesce(pg_catalog.jsonb_agg(source_type order by source_type), '[]'::jsonb)
  from stale;
$$;

create function atlas_core.rmvp_03b_all_history_items(
  input_set_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with evaluation_items as (
    select
      evaluation.evaluated_at as occurred_at,
      1 as history_kind_rank,
      evaluation.planning_input_evaluation_id as history_item_id,
      pg_catalog.jsonb_build_object(
        'history_kind', 'EVALUATION',
        'history_kind_rank', 1,
        'history_item_id', evaluation.planning_input_evaluation_id,
        'occurred_at', evaluation.evaluated_at,
        'evaluation', pg_catalog.jsonb_build_object(
          'planning_input_evaluation_id', evaluation.planning_input_evaluation_id,
          'evaluation_version', evaluation.evaluation_version,
          'evaluation_result', evaluation.evaluation_result,
          'blocking_issue_count', evaluation.blocking_issue_count,
          'warning_count', evaluation.warning_count,
          'evaluated_by_actor_id', evaluation.evaluated_by_actor_id,
          'evaluated_by_display_name', actor.display_name,
          'evaluated_at', evaluation.evaluated_at,
          'source_bindings', pg_catalog.jsonb_build_object(
            'weekly_menu', case when evaluation.weekly_menu_id is null then null else pg_catalog.jsonb_build_object(
              'weekly_menu_id', evaluation.weekly_menu_id,
              'weekly_menu_version', evaluation.weekly_menu_version,
              'weekly_menu_approval_snapshot_id', evaluation.weekly_menu_approval_snapshot_id
            ) end,
            'attendance', case when evaluation.attendance_batch_id is null then null else pg_catalog.jsonb_build_object(
              'attendance_batch_id', evaluation.attendance_batch_id,
              'attendance_version', evaluation.attendance_version,
              'attendance_approval_snapshot_id', evaluation.attendance_approval_snapshot_id
            ) end,
            'pantry', case when evaluation.pantry_need_batch_id is null then null else pg_catalog.jsonb_build_object(
              'pantry_need_batch_id', evaluation.pantry_need_batch_id,
              'pantry_need_batch_version', evaluation.pantry_need_batch_version,
              'pantry_need_approval_snapshot_id', evaluation.pantry_need_approval_snapshot_id
            ) end
          ),
          'historical_pantry_state', case when evaluation.pantry_need_batch_id is null then 'PRE_PANTRY_NULL_BINDING' else 'BOUND' end,
          'can_authorize_need_generation_request', evaluation.pantry_need_batch_id is not null,
          'issues', coalesce((
            select pg_catalog.jsonb_agg(
              pg_catalog.jsonb_build_object(
                'planning_input_readiness_issue_id', issue.planning_input_readiness_issue_id,
                'severity', issue.severity,
                'issue_code', issue.issue_code,
                'safe_message', issue.message,
                'input_type', issue.input_type,
                'school_id', issue.school_id,
                'service_date', issue.service_date
              ) order by case issue.severity when 'BLOCKING' then 1 else 2 end,
                issue.issue_code, issue.school_id, issue.service_date,
                issue.planning_input_readiness_issue_id
            )
            from atlas_planning.planning_input_evaluation_issues issue
            where issue.planning_input_evaluation_id = evaluation.planning_input_evaluation_id
          ), '[]'::jsonb)
        )
      ) as item
    from atlas_planning.planning_input_evaluations evaluation
    join atlas_core.actors actor on actor.actor_id = evaluation.evaluated_by_actor_id
    where evaluation.planning_input_set_id = input_set_id
  ), command_items as (
    select
      event.occurred_at,
      case event.event_type
        when 'PlanningInputNeedGenerationRequested' then 2 else 3 end
        as history_kind_rank,
      event.domain_event_id as history_item_id,
      pg_catalog.jsonb_build_object(
        'history_kind', case event.event_type
          when 'PlanningInputNeedGenerationRequested' then 'NEED_GENERATION_REQUEST'
          else 'INVALIDATION' end,
        'history_kind_rank', case event.event_type
          when 'PlanningInputNeedGenerationRequested' then 2 else 3 end,
        'history_item_id', event.domain_event_id,
        'occurred_at', event.occurred_at,
        'domain_event_id', event.domain_event_id,
        'audit_event_id', audit.audit_event_id,
        'command_id', event.command_id,
        'correlation_id', event.correlation_id,
        'actor_id', event.actor_id,
        'actor_display_name', actor.display_name,
        'prior_status', audit.before_summary ->> 'readiness_status',
        'next_status', audit.after_summary ->> 'readiness_status',
        'planning_input_evaluation_id', audit.after_summary ->> 'planning_input_evaluation_id',
        'current_evaluation_version', audit.after_summary -> 'current_evaluation_version',
        'reason_code', audit.reason_code,
        'reason_note', audit.reason_note
      ) as item
    from atlas_audit.domain_events event
    join atlas_audit.audit_events audit
      on audit.command_id = event.command_id
     and audit.aggregate_id = event.aggregate_id
     and audit.event_type = event.event_type
    join atlas_core.actors actor on actor.actor_id = event.actor_id
    where event.aggregate_type = 'PlanningInputSet'
      and event.aggregate_id = input_set_id
      and event.event_type in (
        'PlanningInputNeedGenerationRequested',
        'PlanningInputReadinessInvalidated'
      )
  ), all_items as (
    select * from evaluation_items
    union all
    select * from command_items
  )
  select coalesce(
    pg_catalog.jsonb_agg(item order by occurred_at desc, history_kind_rank, history_item_id desc),
    '[]'::jsonb
  )
  from all_items;
$$;

create function atlas_core.rmvp_03b_history_page(
  input_set_id uuid,
  period_start date,
  period_end date,
  history_limit integer,
  history_cursor text default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_all jsonb := atlas_core.rmvp_03b_all_history_items(input_set_id);
  v_cursor jsonb;
  v_high_time timestamptz;
  v_high_rank integer;
  v_high_id uuid;
  v_last_time timestamptz;
  v_last_rank integer;
  v_last_id uuid;
  v_page jsonb;
  v_returned jsonb;
  v_has_more boolean;
  v_next text;
  v_count integer;
  v_new_last jsonb;
begin
  if history_cursor is null then
    select
      (item ->> 'occurred_at')::timestamptz,
      (item ->> 'history_kind_rank')::integer,
      (item ->> 'history_item_id')::uuid
    into v_high_time, v_high_rank, v_high_id
    from pg_catalog.jsonb_array_elements(v_all) with ordinality source(item, ordinal)
    order by ordinal limit 1;
  else
    begin
      v_cursor := pg_catalog.convert_from(
        pg_catalog.decode(history_cursor, 'base64'), 'UTF8'
      )::jsonb;
      if v_cursor ->> 'version' <> 'RMVP-03B.cursor.v1'
        or atlas_core.rmvp_03b_safe_date(v_cursor ->> 'period_start') is distinct from period_start
        or atlas_core.rmvp_03b_safe_date(v_cursor ->> 'period_end') is distinct from period_end
      then
        raise exception 'invalid cursor';
      end if;
      v_high_time := (v_cursor ->> 'high_occurred_at')::timestamptz;
      v_high_rank := (v_cursor ->> 'high_kind_rank')::integer;
      v_high_id := (v_cursor ->> 'high_item_id')::uuid;
      v_last_time := (v_cursor ->> 'last_occurred_at')::timestamptz;
      v_last_rank := (v_cursor ->> 'last_kind_rank')::integer;
      v_last_id := (v_cursor ->> 'last_item_id')::uuid;
      if not exists (
        select 1 from pg_catalog.jsonb_array_elements(v_all) item
        where (item ->> 'occurred_at')::timestamptz = v_high_time
          and (item ->> 'history_kind_rank')::integer = v_high_rank
          and (item ->> 'history_item_id')::uuid = v_high_id
      ) or not exists (
        select 1 from pg_catalog.jsonb_array_elements(v_all) item
        where (item ->> 'occurred_at')::timestamptz = v_last_time
          and (item ->> 'history_kind_rank')::integer = v_last_rank
          and (item ->> 'history_item_id')::uuid = v_last_id
      ) then
        raise exception 'cursor evidence missing';
      end if;
    exception when others then
      return pg_catalog.jsonb_build_object(
        'validation_error', 'INVALID_HISTORY_CURSOR'
      );
    end;
  end if;

  with eligible as (
    select item,
      (item ->> 'occurred_at')::timestamptz as occurred_at,
      (item ->> 'history_kind_rank')::integer as kind_rank,
      (item ->> 'history_item_id')::uuid as item_id
    from pg_catalog.jsonb_array_elements(v_all) item
    where v_high_time is null or (
      (item ->> 'occurred_at')::timestamptz < v_high_time
      or ((item ->> 'occurred_at')::timestamptz = v_high_time and (
        (item ->> 'history_kind_rank')::integer > v_high_rank
        or ((item ->> 'history_kind_rank')::integer = v_high_rank
          and (item ->> 'history_item_id')::uuid <= v_high_id)
      ))
    )
      and (history_cursor is null or (
        (item ->> 'occurred_at')::timestamptz < v_last_time
        or ((item ->> 'occurred_at')::timestamptz = v_last_time and (
          (item ->> 'history_kind_rank')::integer > v_last_rank
          or ((item ->> 'history_kind_rank')::integer = v_last_rank
            and (item ->> 'history_item_id')::uuid < v_last_id)
        ))
      ))
    order by occurred_at desc, kind_rank, item_id desc
    limit history_limit + 1
  )
  select coalesce(pg_catalog.jsonb_agg(item order by occurred_at desc, kind_rank, item_id desc), '[]'::jsonb)
  into v_page from eligible;

  v_count := pg_catalog.jsonb_array_length(v_page);
  v_has_more := v_count > history_limit;
  select coalesce(pg_catalog.jsonb_agg(item - 'history_kind_rank' order by ordinal), '[]'::jsonb)
  into v_returned
  from pg_catalog.jsonb_array_elements(v_page) with ordinality source(item, ordinal)
  where ordinal <= history_limit;
  if v_has_more then
    v_new_last := v_page -> (history_limit - 1);
    v_next := pg_catalog.replace(
      pg_catalog.encode(
        pg_catalog.convert_to(
          pg_catalog.jsonb_build_object(
            'version', 'RMVP-03B.cursor.v1',
            'period_start', period_start,
            'period_end', period_end,
            'high_occurred_at', v_high_time,
            'high_kind_rank', v_high_rank,
            'high_item_id', v_high_id,
            'last_occurred_at', v_new_last ->> 'occurred_at',
            'last_kind_rank', v_new_last ->> 'history_kind_rank',
            'last_item_id', v_new_last ->> 'history_item_id'
          )::text,
          'UTF8'
        ),
        'base64'
      ),
      E'\n',
      ''
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'items', v_returned,
    'has_more', v_has_more,
    'next_cursor', v_next
  );
end;
$$;

create function atlas_core.rmvp_03b_workbench_payload(
  period_start date,
  period_end date,
  source_selection jsonb default null,
  history_limit integer default 25,
  history_cursor text default null
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
  v_weekly jsonb;
  v_attendance jsonb;
  v_pantry jsonb;
  v_root jsonb;
  v_current jsonb;
  v_history jsonb;
  v_can_evaluate boolean;
  v_can_request boolean := false;
  v_can_invalidate boolean := false;
  v_stale_types jsonb := '[]'::jsonb;
  v_invalidation_reasons jsonb := '[]'::jsonb;
  v_disabled jsonb := '[]'::jsonb;
  v_selection jsonb := coalesce(source_selection, '{}'::jsonb);
begin
  v_weekly := atlas_core.rmvp_03b_source_evidence(
    'WEEKLY_MENU', period_start, period_end,
    nullif(v_selection -> 'weekly_menu', 'null'::jsonb)
  );
  v_attendance := atlas_core.rmvp_03b_source_evidence(
    'ATTENDANCE', period_start, period_end,
    nullif(v_selection -> 'attendance', 'null'::jsonb)
  );
  v_pantry := atlas_core.rmvp_03b_source_evidence(
    'PANTRY', period_start, period_end,
    nullif(v_selection -> 'pantry', 'null'::jsonb)
  );
  if v_weekly ? 'validation_error' then return v_weekly; end if;
  if v_attendance ? 'validation_error' then return v_attendance; end if;
  if v_pantry ? 'validation_error' then return v_pantry; end if;

  select * into v_set
  from atlas_planning.planning_input_sets input_set
  where input_set.period_start = rmvp_03b_workbench_payload.period_start
    and input_set.period_end = rmvp_03b_workbench_payload.period_end;
  if v_set.planning_input_set_id is not null then
    select * into v_evaluation
    from atlas_planning.planning_input_evaluations evaluation
    where evaluation.planning_input_evaluation_id = v_set.current_evaluation_id;
    v_root := pg_catalog.jsonb_build_object(
      'planning_input_set_id', v_set.planning_input_set_id,
      'readiness_status', v_set.readiness_status,
      'current_evaluation_id', v_set.current_evaluation_id,
      'created_at', v_set.created_at,
      'updated_at', v_set.updated_at
    );
    v_current := pg_catalog.jsonb_build_object(
      'planning_input_evaluation_id', v_evaluation.planning_input_evaluation_id,
      'evaluation_version', v_evaluation.evaluation_version,
      'evaluation_result', v_evaluation.evaluation_result,
      'blocking_issue_count', v_evaluation.blocking_issue_count,
      'warning_count', v_evaluation.warning_count,
      'evaluated_by_actor_id', v_evaluation.evaluated_by_actor_id,
      'evaluated_by_display_name', (select actor.display_name from atlas_core.actors actor where actor.actor_id = v_evaluation.evaluated_by_actor_id),
      'evaluated_at', v_evaluation.evaluated_at,
      'source_bindings', pg_catalog.jsonb_build_object(
        'weekly_menu', case when v_evaluation.weekly_menu_id is null then null else pg_catalog.jsonb_build_object(
          'weekly_menu_id', v_evaluation.weekly_menu_id,
          'weekly_menu_version', v_evaluation.weekly_menu_version,
          'weekly_menu_approval_snapshot_id', v_evaluation.weekly_menu_approval_snapshot_id
        ) end,
        'attendance', case when v_evaluation.attendance_batch_id is null then null else pg_catalog.jsonb_build_object(
          'attendance_batch_id', v_evaluation.attendance_batch_id,
          'attendance_version', v_evaluation.attendance_version,
          'attendance_approval_snapshot_id', v_evaluation.attendance_approval_snapshot_id
        ) end,
        'pantry', case when v_evaluation.pantry_need_batch_id is null then null else pg_catalog.jsonb_build_object(
          'pantry_need_batch_id', v_evaluation.pantry_need_batch_id,
          'pantry_need_batch_version', v_evaluation.pantry_need_batch_version,
          'pantry_need_approval_snapshot_id', v_evaluation.pantry_need_approval_snapshot_id
        ) end
      ),
      'issues', pg_catalog.jsonb_build_object(
        'blockers', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'planning_input_readiness_issue_id', issue.planning_input_readiness_issue_id,
          'severity', issue.severity, 'issue_code', issue.issue_code,
          'safe_message', issue.message, 'input_type', issue.input_type,
          'school_id', issue.school_id, 'service_date', issue.service_date
        ) order by issue.issue_code, issue.school_id, issue.service_date)
          from atlas_planning.planning_input_evaluation_issues issue
          where issue.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'), '[]'::jsonb),
        'warnings', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'planning_input_readiness_issue_id', issue.planning_input_readiness_issue_id,
          'severity', issue.severity, 'issue_code', issue.issue_code,
          'safe_message', issue.message, 'input_type', issue.input_type,
          'school_id', issue.school_id, 'service_date', issue.service_date
        ) order by issue.issue_code, issue.school_id, issue.service_date)
          from atlas_planning.planning_input_evaluation_issues issue
          where issue.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id
            and issue.severity = 'WARNING'), '[]'::jsonb)
      )
    );
    v_stale_types := atlas_core.rmvp_03b_stale_source_types(
      v_evaluation.planning_input_evaluation_id, period_start, period_end
    );
    v_can_request := v_set.readiness_status = 'READY'
      and v_evaluation.evaluation_result = 'READY'
      and v_evaluation.blocking_issue_count = 0
      and atlas_core.rmvp_03b_bindings_current(
        v_evaluation.planning_input_evaluation_id, period_start, period_end
      );
    v_can_invalidate := v_set.readiness_status in (
      'READY', 'NEED_GENERATION_REQUESTED'
    );
    if v_can_invalidate then
      v_invalidation_reasons := pg_catalog.jsonb_build_array(
        'PLANNING_REVIEW_CORRECTION'
      );
      if pg_catalog.jsonb_array_length(v_stale_types) > 0 then
        v_invalidation_reasons := v_invalidation_reasons ||
          pg_catalog.jsonb_build_array('UPSTREAM_SOURCE_CHANGED');
      end if;
      if v_set.readiness_status = 'NEED_GENERATION_REQUESTED'
        and not exists (
          select 1 from atlas_planning.need_generation_runs run
          where run.planning_input_set_id = v_set.planning_input_set_id
            and run.planning_input_evaluation_id = v_set.current_evaluation_id
        )
      then
        v_invalidation_reasons := v_invalidation_reasons ||
          pg_catalog.jsonb_build_array('NEED_GENERATION_REQUEST_WITHDRAWN');
      end if;
    end if;
  end if;
  v_can_evaluate := coalesce(v_set.readiness_status in ('NOT_READY', 'INVALIDATED'), true)
    and v_weekly ->> 'selection_state' in ('SELECTED', 'MISSING')
    and v_attendance ->> 'selection_state' in ('SELECTED', 'MISSING')
    and v_pantry ->> 'selection_state' in ('SELECTED', 'MISSING');
  if not v_can_evaluate then
    v_disabled := v_disabled || pg_catalog.jsonb_build_array(
      'Readiness evaluation requires an eligible lifecycle and resolved current candidates.'
    );
  end if;
  if not v_can_request then
    v_disabled := v_disabled || pg_catalog.jsonb_build_array(
      'Need Generation request requires the exact current READY evaluation and all three current bindings.'
    );
  end if;
  v_history := atlas_core.rmvp_03b_history_page(
    v_set.planning_input_set_id, period_start, period_end,
    history_limit, history_cursor
  );
  if v_history ? 'validation_error' then return v_history; end if;
  return pg_catalog.jsonb_build_object(
    'period', pg_catalog.jsonb_build_object(
      'period_start', period_start,
      'period_end', period_end,
      'inclusive', true,
      'monday_week_convenience', pg_catalog.jsonb_build_object(
        'week_start', period_start - (extract(isodow from period_start)::integer - 1),
        'week_end', period_start - (extract(isodow from period_start)::integer - 1) + 6
      )
    ),
    'decision', coalesce(v_set.readiness_status, 'NOT_EVALUATED'),
    'root', v_root,
    'current_evaluation', v_current,
    'source_evidence', pg_catalog.jsonb_build_object(
      'weekly_menu', v_weekly,
      'attendance', v_attendance,
      'pantry', v_pantry
    ),
    'allowed_actions', pg_catalog.jsonb_build_object(
      'can_evaluate', v_can_evaluate,
      'can_request_need_generation', v_can_request,
      'can_invalidate', v_can_invalidate,
      'invalidation_reason_codes', v_invalidation_reasons,
      'disabled_reasons', v_disabled
    ),
    'history_items', v_history -> 'items',
    'history_next_cursor', v_history -> 'next_cursor',
    'history_has_more', v_history -> 'has_more'
  );
end;
$$;

create function atlas_core.rmvp_03b_begin_receipt(
  request jsonb,
  actor_id uuid,
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
  v_receipt atlas_core.command_receipts%rowtype;
  v_hash text := atlas_core.rmvp_03b_sha256(request);
  v_inserted uuid;
begin
  select * into v_receipt
  from atlas_core.command_receipts receipt
  where receipt.command_id = atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
  for update;
  if found then
    if v_receipt.command_name <> command_name
      or v_receipt.scope_key <> scope_key
      or v_receipt.idempotency_key <> request ->> 'idempotency_key'
      or v_receipt.actor_id <> actor_id
      or v_receipt.request_hash <> v_hash
    then
      return pg_catalog.jsonb_build_object(
        'status', 'ERROR',
        'response', atlas_core.rmvp_03b_error(
          request, command_name, 'IDEMPOTENCY_CONFLICT',
          'The command identity is already bound to a different intent.'
        )
      );
    end if;
    if v_receipt.outcome in ('COMPLETED', 'FAILED_NON_RETRYABLE') then
      return pg_catalog.jsonb_build_object(
        'status', 'REPLAY', 'response', v_receipt.response_payload
      );
    end if;
    return pg_catalog.jsonb_build_object(
      'status', 'ERROR',
      'response', atlas_core.rmvp_03b_error(
        request, command_name, 'RETRYABLE_CONCURRENCY_FAILURE',
        'The same command is currently being processed.', false, true
      )
    );
  end if;

  select * into v_receipt
  from atlas_core.command_receipts receipt
  where receipt.scope_key = rmvp_03b_begin_receipt.scope_key
    and receipt.command_name = rmvp_03b_begin_receipt.command_name
    and receipt.idempotency_key = request ->> 'idempotency_key'
  for update;
  if found then
    if v_receipt.command_id <>
        atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
      or v_receipt.actor_id <> actor_id
      or v_receipt.request_hash <> v_hash
    then
      return pg_catalog.jsonb_build_object(
        'status', 'ERROR',
        'response', atlas_core.rmvp_03b_error(
          request, command_name, 'IDEMPOTENCY_CONFLICT',
          'The idempotency key is already bound to a different intent.'
        )
      );
    end if;
    if v_receipt.outcome in ('COMPLETED', 'FAILED_NON_RETRYABLE') then
      return pg_catalog.jsonb_build_object(
        'status', 'REPLAY', 'response', v_receipt.response_payload
      );
    end if;
    return pg_catalog.jsonb_build_object(
      'status', 'ERROR',
      'response', atlas_core.rmvp_03b_error(
        request, command_name, 'RETRYABLE_CONCURRENCY_FAILURE',
        'The same command is currently being processed.', false, true
      )
    );
  end if;

  insert into atlas_core.command_receipts (
    command_name,
    scope_key,
    idempotency_key,
    command_id,
    correlation_id,
    actor_id,
    expected_version,
    request_hash,
    outcome
  ) values (
    command_name,
    scope_key,
    request ->> 'idempotency_key',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id,
    atlas_core.pa_05b_safe_bigint(
      request ->> 'expected_current_evaluation_version'
    ),
    v_hash,
    'IN_PROGRESS'
  )
  on conflict do nothing
  returning command_receipt_id into v_inserted;

  if v_inserted is null then
    return pg_catalog.jsonb_build_object(
      'status', 'ERROR',
      'response', atlas_core.rmvp_03b_error(
        request, command_name, 'RETRYABLE_CONCURRENCY_FAILURE',
        'The command identity is being registered concurrently.', false, true
      )
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY', 'receipt_id', v_inserted
  );
end;
$$;

create function atlas_core.rmvp_03b_prepare_command(
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
  v_actor_id uuid;
  v_begin jsonb;
begin
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
    'status', 'READY',
    'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

create function atlas_core.rmvp_03b_finish_error(
  receipt_id uuid,
  response jsonb
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $$
  select atlas_core.pa_05b_finish_command(receipt_id, response, false);
$$;

create function atlas_core.rmvp_03b_record_change(
  request jsonb,
  actor_id uuid,
  receipt_id uuid,
  event_type text,
  input_set_id uuid,
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
    event_type, 'PLANNING', 'PlanningInputSet', input_set_id,
    null, receipt_id,
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
    event_type, 'PLANNING', 'PlanningInputSet', input_set_id,
    null, null, receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id, request ->> 'reason_code',
    atlas_core.rmvp_03b_normalize_text(request ->> 'reason_note'),
    before_summary, after_summary, 'atlas_api',
    pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_id;
  return pg_catalog.jsonb_build_object(
    'domain_event_id', v_event_id,
    'audit_event_id', v_audit_id
  );
end;
$$;

create function atlas_core.rmvp_03b_finish_success(
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

create function atlas_api.get_planning_input_readiness_workbench(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_planning_input_readiness_workbench';
  v_error jsonb;
  v_context jsonb;
  v_payload jsonb;
  v_start date;
  v_end date;
  v_limit integer;
begin
  v_error := atlas_core.rmvp_03b_validate_read(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_03b_authorize_global(
    request, 'planning.inputs.read', v_name, true
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_start := atlas_core.rmvp_03b_safe_date(
    request -> 'payload' ->> 'period_start'
  );
  v_end := atlas_core.rmvp_03b_safe_date(
    request -> 'payload' ->> 'period_end'
  );
  v_limit := coalesce(atlas_core.pa_05b_safe_bigint(
    request -> 'payload' ->> 'history_limit'
  )::integer, 25);
  v_payload := atlas_core.rmvp_03b_workbench_payload(
    v_start, v_end,
    request -> 'payload' -> 'source_selection',
    v_limit,
    nullif(request -> 'payload' ->> 'history_cursor', '')
  );
  if v_payload ? 'validation_error' then
    return atlas_core.rmvp_03b_error(
      request, v_name,
      case v_payload ->> 'validation_error'
        when 'MALFORMED_SOURCE_SELECTION' then 'VALIDATION_FAILED'
        when 'FOREIGN_PERIOD_SOURCE_SELECTION' then 'VALIDATION_FAILED'
        else v_payload ->> 'validation_error' end,
      'The source selection or history cursor is not valid for this exact period.',
      true
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-03B.v1',
    'correlation_id', request ->> 'correlation_id',
    'workbench', v_payload
  );
exception when others then
  return atlas_core.rmvp_03b_error(
    request, v_name, 'INTERNAL_READ_FAILURE',
    'Planning Input Readiness could not be returned safely.', true
  );
end;
$$;

create function atlas_api.evaluate_planning_input_readiness(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'evaluate_planning_input_readiness';
  v_error jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_start date;
  v_end date;
  v_candidates jsonb;
  v_weekly_input jsonb;
  v_attendance_input jsonb;
  v_pantry_input jsonb;
  v_weekly jsonb;
  v_attendance jsonb;
  v_pantry jsonb;
  v_set atlas_planning.planning_input_sets%rowtype;
  v_current atlas_planning.planning_input_evaluations%rowtype;
  v_set_id uuid;
  v_evaluation_id uuid := gen_random_uuid();
  v_version bigint;
  v_issues jsonb;
  v_blockers integer;
  v_warnings integer;
  v_result text;
  v_before jsonb;
  v_after jsonb;
  v_selection jsonb;
begin
  v_error := atlas_core.rmvp_03b_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;
  if request ->> 'reason_code' <> 'READINESS_EVALUATION_REQUESTED'
    or request -> 'reason_note' <> 'null'::jsonb
    or pg_catalog.jsonb_typeof(
      request -> 'payload' -> 'source_candidates'
    ) is distinct from 'object'
    or not (request -> 'payload' -> 'source_candidates' ?&
      array['weekly_menu', 'attendance', 'pantry'])
  then
    return atlas_core.rmvp_03b_error(
      request, v_name, 'VALIDATION_FAILED',
      'Evaluation requires the fixed reason and all three nullable typed source candidates.'
    );
  end if;
  v_start := atlas_core.rmvp_03b_safe_date(request -> 'payload' ->> 'period_start');
  v_end := atlas_core.rmvp_03b_safe_date(request -> 'payload' ->> 'period_end');
  v_candidates := request -> 'payload' -> 'source_candidates';
  v_weekly_input := nullif(v_candidates -> 'weekly_menu', 'null'::jsonb);
  v_attendance_input := nullif(v_candidates -> 'attendance', 'null'::jsonb);
  v_pantry_input := nullif(v_candidates -> 'pantry', 'null'::jsonb);
  v_prepare := atlas_core.rmvp_03b_prepare_command(
    request, v_name, 'READINESS:' || v_start::text || ':' || v_end::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('RMVP-03B:' || v_start::text || ':' || v_end::text, 0)
  );
  select * into v_set
  from atlas_planning.planning_input_sets input_set
  where input_set.period_start = v_start and input_set.period_end = v_end
  for update;
  if v_set.planning_input_set_id is null then
    if request ->> 'expected_root_status' <> 'ABSENT' then
      v_error := atlas_core.rmvp_03b_error(
        request, v_name, 'STALE_ROOT_STATE',
        'The current readiness root state differs from the reviewed expectation.',
        false, false, '[]'::jsonb, '[]'::jsonb, 'ABSENT'
      );
      return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
    end if;
    v_set_id := gen_random_uuid();
    v_version := 1;
    v_before := pg_catalog.jsonb_build_object('readiness_status', 'ABSENT');
  else
    select * into v_current
    from atlas_planning.planning_input_evaluations evaluation
    where evaluation.planning_input_evaluation_id = v_set.current_evaluation_id;
    if request ->> 'expected_root_status' is distinct from v_set.readiness_status then
      v_error := atlas_core.rmvp_03b_error(
        request, v_name, 'STALE_ROOT_STATE',
        'The current readiness root state differs from the reviewed expectation.',
        false, false, '[]'::jsonb, '[]'::jsonb,
        v_set.readiness_status, v_set.current_evaluation_id,
        v_current.evaluation_version
      );
      return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
    end if;
    if atlas_core.pa_05b_safe_uuid(request ->> 'expected_current_evaluation_id')
        is distinct from v_set.current_evaluation_id
      or atlas_core.pa_05b_safe_bigint(request ->> 'expected_current_evaluation_version')
        is distinct from v_current.evaluation_version
    then
      v_error := atlas_core.rmvp_03b_error(
        request, v_name, 'STALE_CURRENT_EVALUATION',
        'The current readiness evaluation differs from the reviewed expectation.',
        false, false, '[]'::jsonb, '[]'::jsonb,
        v_set.readiness_status, v_set.current_evaluation_id,
        v_current.evaluation_version
      );
      return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
    end if;
    if v_set.readiness_status not in ('NOT_READY', 'INVALIDATED') then
      v_error := atlas_core.rmvp_03b_error(
        request, v_name, 'INVALID_LIFECYCLE_STATE',
        'The current readiness state does not permit evaluation.',
        false, false, '[]'::jsonb, '[]'::jsonb,
        v_set.readiness_status, v_set.current_evaluation_id,
        v_current.evaluation_version
      );
      return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
    end if;
    v_set_id := v_set.planning_input_set_id;
    v_version := v_current.evaluation_version + 1;
    v_before := pg_catalog.jsonb_build_object(
      'readiness_status', v_set.readiness_status,
      'planning_input_evaluation_id', v_set.current_evaluation_id,
      'current_evaluation_version', v_current.evaluation_version
    );
  end if;

  v_weekly := atlas_core.rmvp_03b_source_evidence('WEEKLY_MENU', v_start, v_end, v_weekly_input);
  v_attendance := atlas_core.rmvp_03b_source_evidence('ATTENDANCE', v_start, v_end, v_attendance_input);
  v_pantry := atlas_core.rmvp_03b_source_evidence('PANTRY', v_start, v_end, v_pantry_input);
  if v_weekly ? 'validation_error' or v_attendance ? 'validation_error' or v_pantry ? 'validation_error' then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name,
      case
        when coalesce(v_weekly ->> 'validation_error', v_attendance ->> 'validation_error', v_pantry ->> 'validation_error') = 'SOURCE_CANDIDATE_OWNERSHIP_MISMATCH'
          then 'SOURCE_CANDIDATE_OWNERSHIP_MISMATCH'
        else 'VALIDATION_FAILED' end,
      'A selected source candidate is malformed, foreign to the period, or not owned by its source root.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  if (v_weekly_input is null and v_weekly ->> 'selection_state' <> 'MISSING')
    or (v_attendance_input is null and v_attendance ->> 'selection_state' <> 'MISSING')
    or (v_pantry_input is null and v_pantry ->> 'selection_state' <> 'MISSING')
  then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name,
      case when v_weekly ->> 'selection_state' = 'AMBIGUOUS'
          or v_attendance ->> 'selection_state' = 'AMBIGUOUS'
          or v_pantry ->> 'selection_state' = 'AMBIGUOUS'
        then 'AMBIGUOUS_SOURCE_CANDIDATE'
        else 'VALIDATION_FAILED' end,
      'Every available source candidate must be selected explicitly for evaluation.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  if (v_weekly_input is not null and v_weekly ->> 'selection_state' <> 'SELECTED')
    or (v_attendance_input is not null and v_attendance ->> 'selection_state' <> 'SELECTED')
    or (v_pantry_input is not null and v_pantry ->> 'selection_state' <> 'SELECTED')
  then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'STALE_SOURCE_CANDIDATE',
      'A selected source candidate is no longer current.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;

  if v_weekly_input is not null then
    perform 1 from atlas_planning.weekly_menus menu
    where menu.weekly_menu_id = atlas_core.pa_05b_safe_uuid(v_weekly_input ->> 'weekly_menu_id')
    for update;
  end if;
  if v_attendance_input is not null then
    perform 1 from atlas_planning.attendance_batches batch
    where batch.attendance_batch_id = atlas_core.pa_05b_safe_uuid(v_attendance_input ->> 'attendance_batch_id')
    for update;
  end if;
  if v_pantry_input is not null then
    perform 1 from atlas_planning.pantry_need_batches batch
    where batch.pantry_need_batch_id = atlas_core.pa_05b_safe_uuid(v_pantry_input ->> 'pantry_need_batch_id')
    for update;
  end if;
  v_weekly := atlas_core.rmvp_03b_source_evidence('WEEKLY_MENU', v_start, v_end, v_weekly_input);
  v_attendance := atlas_core.rmvp_03b_source_evidence('ATTENDANCE', v_start, v_end, v_attendance_input);
  v_pantry := atlas_core.rmvp_03b_source_evidence('PANTRY', v_start, v_end, v_pantry_input);
  if (v_weekly_input is not null and v_weekly ->> 'selection_state' <> 'SELECTED')
    or (v_attendance_input is not null and v_attendance ->> 'selection_state' <> 'SELECTED')
    or (v_pantry_input is not null and v_pantry ->> 'selection_state' <> 'SELECTED')
  then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'STALE_SOURCE_CANDIDATE',
      'A selected source candidate changed before evaluation completed.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;

  v_issues := atlas_core.rmvp_03b_calculate_issues(
    v_start, v_end, v_weekly, v_attendance, v_pantry
  );
  select count(*) filter (where issue ->> 'severity' = 'BLOCKING'),
    count(*) filter (where issue ->> 'severity' = 'WARNING')
  into v_blockers, v_warnings
  from pg_catalog.jsonb_array_elements(v_issues) issue;
  v_result := case when v_blockers = 0 then 'READY' else 'NOT_READY' end;

  if v_set.planning_input_set_id is null then
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (v_set_id, v_start, v_end, v_result, v_evaluation_id);
  end if;
  insert into atlas_planning.planning_input_evaluations (
    planning_input_evaluation_id, planning_input_set_id,
    evaluation_version, evaluation_result,
    weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id,
    attendance_batch_id, attendance_version,
    attendance_approval_snapshot_id,
    pantry_need_batch_id, pantry_need_batch_version,
    pantry_need_approval_snapshot_id,
    blocking_issue_count, warning_count, evaluated_by_actor_id
  ) values (
    v_evaluation_id, v_set_id, v_version, v_result,
    atlas_core.pa_05b_safe_uuid(v_weekly_input ->> 'weekly_menu_id'),
    atlas_core.pa_05b_safe_bigint(v_weekly_input ->> 'weekly_menu_version'),
    atlas_core.pa_05b_safe_uuid(v_weekly_input ->> 'weekly_menu_approval_snapshot_id'),
    atlas_core.pa_05b_safe_uuid(v_attendance_input ->> 'attendance_batch_id'),
    atlas_core.pa_05b_safe_bigint(v_attendance_input ->> 'attendance_version'),
    atlas_core.pa_05b_safe_uuid(v_attendance_input ->> 'attendance_approval_snapshot_id'),
    atlas_core.pa_05b_safe_uuid(v_pantry_input ->> 'pantry_need_batch_id'),
    atlas_core.pa_05b_safe_bigint(v_pantry_input ->> 'pantry_need_batch_version'),
    atlas_core.pa_05b_safe_uuid(v_pantry_input ->> 'pantry_need_approval_snapshot_id'),
    v_blockers, v_warnings, v_actor_id
  );
  insert into atlas_planning.planning_input_evaluation_issues (
    planning_input_evaluation_id, planning_input_set_id, evaluation_version,
    severity, issue_code, message, input_type, school_id, service_date
  ) select v_evaluation_id, v_set_id, v_version,
    issue.severity, issue.issue_code, issue.message, issue.input_type,
    issue.school_id, issue.service_date
  from pg_catalog.jsonb_to_recordset(v_issues) issue(
    severity text, issue_code text, message text, input_type text,
    school_id uuid, service_date date
  );
  if v_set.planning_input_set_id is not null then
    update atlas_planning.planning_input_sets input_set
    set readiness_status = v_result,
      current_evaluation_id = v_evaluation_id,
      updated_at = pg_catalog.transaction_timestamp()
    where input_set.planning_input_set_id = v_set_id;
  end if;
  v_after := pg_catalog.jsonb_build_object(
    'readiness_status', v_result,
    'planning_input_evaluation_id', v_evaluation_id,
    'current_evaluation_version', v_version,
    'blocking_issue_count', v_blockers,
    'warning_count', v_warnings,
    'source_bindings', pg_catalog.jsonb_build_object(
      'weekly_menu', v_weekly_input,
      'attendance', v_attendance_input,
      'pantry', v_pantry_input
    )
  );
  v_selection := pg_catalog.jsonb_build_object(
    'weekly_menu', v_weekly_input,
    'attendance', v_attendance_input,
    'pantry', v_pantry_input
  );
  return atlas_core.rmvp_03b_finish_success(
    request, v_actor_id, v_receipt_id,
    'PlanningInputReadinessEvaluated', v_set_id, v_evaluation_id,
    v_version, v_before, v_after,
    case when v_result = 'READY'
      then 'Readiness evaluated: the period is ready for a Need Generation request.'
      else 'Readiness evaluated: blocking issues must be resolved first.' end,
    v_selection
  );
exception when serialization_failure or deadlock_detected then
  return atlas_core.rmvp_03b_error(
    request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Readiness data is being updated. Retry the exact unchanged request.',
    false, true
  );
when others then
  return atlas_core.rmvp_03b_error(
    request, v_name, 'INVARIANT_VIOLATION',
    'The readiness evaluation could not be completed safely.'
  );
end;
$$;

create function atlas_api.request_planning_input_need_generation(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'request_planning_input_need_generation';
  v_error jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_set_id uuid;
  v_start date;
  v_end date;
  v_set atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_before jsonb;
  v_after jsonb;
  v_selection jsonb;
begin
  v_error := atlas_core.rmvp_03b_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;
  if request ->> 'reason_code' <> 'NEED_GENERATION_HANDOFF_REQUESTED'
    or request -> 'reason_note' <> 'null'::jsonb
    or request ->> 'expected_root_status' <> 'READY'
    or (select count(*) from pg_catalog.jsonb_object_keys(request -> 'payload')) <> 3
    or not (request -> 'payload' ?&
      array['planning_input_set_id', 'period_start', 'period_end'])
  then
    return atlas_core.rmvp_03b_error(
      request, v_name, 'VALIDATION_FAILED',
      'The handoff request accepts only the set ID, exact period, fixed reason, and READY expectations.'
    );
  end if;
  v_set_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'planning_input_set_id'
  );
  v_start := atlas_core.rmvp_03b_safe_date(request -> 'payload' ->> 'period_start');
  v_end := atlas_core.rmvp_03b_safe_date(request -> 'payload' ->> 'period_end');
  if v_set_id is null then
    return atlas_core.rmvp_03b_error(
      request, v_name, 'VALIDATION_FAILED',
      'A valid Planning Input Set ID is required.'
    );
  end if;
  v_prepare := atlas_core.rmvp_03b_prepare_command(
    request, v_name, 'PLANNING_INPUT_SET:' || v_set_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select * into v_set
  from atlas_planning.planning_input_sets input_set
  where input_set.planning_input_set_id = v_set_id
  for update;
  if v_set.planning_input_set_id is null
    or v_set.period_start <> v_start or v_set.period_end <> v_end
  then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'NOT_FOUND',
      'No Planning Input Set matches the exact ID and period.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  select * into v_evaluation
  from atlas_planning.planning_input_evaluations evaluation
  where evaluation.planning_input_evaluation_id = v_set.current_evaluation_id;
  if v_set.readiness_status <> request ->> 'expected_root_status' then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'STALE_ROOT_STATE',
      'The current readiness root state differs from the reviewed expectation.',
      false, false, '[]'::jsonb, '[]'::jsonb,
      v_set.readiness_status, v_set.current_evaluation_id,
      v_evaluation.evaluation_version
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'expected_current_evaluation_id')
      is distinct from v_set.current_evaluation_id
    or atlas_core.pa_05b_safe_bigint(request ->> 'expected_current_evaluation_version')
      is distinct from v_evaluation.evaluation_version
  then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'STALE_CURRENT_EVALUATION',
      'The current readiness evaluation differs from the reviewed expectation.',
      false, false, '[]'::jsonb, '[]'::jsonb,
      v_set.readiness_status, v_set.current_evaluation_id,
      v_evaluation.evaluation_version
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  if v_set.readiness_status <> 'READY'
    or v_evaluation.evaluation_result <> 'READY'
  then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'CURRENT_EVALUATION_NOT_READY',
      'The current evaluation is not READY.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  if v_evaluation.blocking_issue_count <> 0 then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'CURRENT_EVALUATION_HAS_BLOCKERS',
      'The current evaluation contains blocking issues.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  if v_evaluation.pantry_need_batch_id is null then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'HISTORICAL_PANTRY_BINDING_REQUIRED',
      'A current Pantry approval binding is required before requesting Need Generation.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  perform 1 from atlas_planning.weekly_menus menu
  where menu.weekly_menu_id = v_evaluation.weekly_menu_id for update;
  perform 1 from atlas_planning.attendance_batches batch
  where batch.attendance_batch_id = v_evaluation.attendance_batch_id for update;
  perform 1 from atlas_planning.pantry_need_batches batch
  where batch.pantry_need_batch_id = v_evaluation.pantry_need_batch_id for update;
  if not atlas_core.rmvp_03b_bindings_current(
    v_evaluation.planning_input_evaluation_id, v_start, v_end
  ) then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'STALE_SOURCE_BINDING',
      'At least one evaluated source binding is no longer current.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'readiness_status', v_set.readiness_status,
    'planning_input_evaluation_id', v_evaluation.planning_input_evaluation_id,
    'current_evaluation_version', v_evaluation.evaluation_version
  );
  update atlas_planning.planning_input_sets input_set
  set readiness_status = 'NEED_GENERATION_REQUESTED',
    updated_at = pg_catalog.transaction_timestamp()
  where input_set.planning_input_set_id = v_set_id;
  v_after := v_before || pg_catalog.jsonb_build_object(
    'readiness_status', 'NEED_GENERATION_REQUESTED',
    'source_bindings', pg_catalog.jsonb_build_object(
      'weekly_menu', pg_catalog.jsonb_build_object(
        'weekly_menu_id', v_evaluation.weekly_menu_id,
        'weekly_menu_version', v_evaluation.weekly_menu_version,
        'weekly_menu_approval_snapshot_id', v_evaluation.weekly_menu_approval_snapshot_id
      ),
      'attendance', pg_catalog.jsonb_build_object(
        'attendance_batch_id', v_evaluation.attendance_batch_id,
        'attendance_version', v_evaluation.attendance_version,
        'attendance_approval_snapshot_id', v_evaluation.attendance_approval_snapshot_id
      ),
      'pantry', pg_catalog.jsonb_build_object(
        'pantry_need_batch_id', v_evaluation.pantry_need_batch_id,
        'pantry_need_batch_version', v_evaluation.pantry_need_batch_version,
        'pantry_need_approval_snapshot_id', v_evaluation.pantry_need_approval_snapshot_id
      )
    )
  );
  v_selection := v_after -> 'source_bindings';
  return atlas_core.rmvp_03b_finish_success(
    request, v_actor_id, v_receipt_id,
    'PlanningInputNeedGenerationRequested', v_set_id,
    v_evaluation.planning_input_evaluation_id,
    v_evaluation.evaluation_version, v_before, v_after,
    'Need Generation handoff requested; no run or requirement quantity was created.',
    v_selection
  );
exception when serialization_failure or deadlock_detected then
  return atlas_core.rmvp_03b_error(
    request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Readiness data is being updated. Retry the exact unchanged request.',
    false, true
  );
when others then
  return atlas_core.rmvp_03b_error(
    request, v_name, 'INVARIANT_VIOLATION',
    'The handoff request could not be recorded safely.'
  );
end;
$$;

create function atlas_api.invalidate_planning_input_readiness(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'invalidate_planning_input_readiness';
  v_error jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_set_id uuid;
  v_start date;
  v_end date;
  v_reason text;
  v_note text;
  v_set atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_stale_types jsonb;
  v_before jsonb;
  v_after jsonb;
  v_selection jsonb;
begin
  v_error := atlas_core.rmvp_03b_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;
  v_reason := request ->> 'reason_code';
  v_note := atlas_core.rmvp_03b_normalize_text(request ->> 'reason_note');
  if v_reason not in (
      'UPSTREAM_SOURCE_CHANGED',
      'PLANNING_REVIEW_CORRECTION',
      'NEED_GENERATION_REQUEST_WITHDRAWN'
    )
    or request ->> 'expected_root_status' not in (
      'READY', 'NEED_GENERATION_REQUESTED'
    )
    or (select count(*) from pg_catalog.jsonb_object_keys(request -> 'payload')) <> 3
    or not (request -> 'payload' ?&
      array['planning_input_set_id', 'period_start', 'period_end'])
  then
    return atlas_core.rmvp_03b_error(
      request, v_name, 'INVALID_INVALIDATION_REASON',
      'The invalidation request or reason is not permitted.'
    );
  end if;
  if v_reason in (
      'PLANNING_REVIEW_CORRECTION',
      'NEED_GENERATION_REQUEST_WITHDRAWN'
    ) and v_note is null
  then
    return atlas_core.rmvp_03b_error(
      request, v_name, 'REASON_NOTE_REQUIRED',
      'A specific nonblank reason note is required.'
    );
  end if;
  v_set_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'planning_input_set_id'
  );
  v_start := atlas_core.rmvp_03b_safe_date(request -> 'payload' ->> 'period_start');
  v_end := atlas_core.rmvp_03b_safe_date(request -> 'payload' ->> 'period_end');
  if v_set_id is null then
    return atlas_core.rmvp_03b_error(
      request, v_name, 'VALIDATION_FAILED',
      'A valid Planning Input Set ID is required.'
    );
  end if;
  v_prepare := atlas_core.rmvp_03b_prepare_command(
    request, v_name, 'PLANNING_INPUT_SET:' || v_set_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_set
  from atlas_planning.planning_input_sets input_set
  where input_set.planning_input_set_id = v_set_id
  for update;
  if v_set.planning_input_set_id is null
    or v_set.period_start <> v_start or v_set.period_end <> v_end
  then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'NOT_FOUND',
      'No Planning Input Set matches the exact ID and period.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  select * into v_evaluation
  from atlas_planning.planning_input_evaluations evaluation
  where evaluation.planning_input_evaluation_id = v_set.current_evaluation_id;
  if v_set.readiness_status <> request ->> 'expected_root_status' then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'STALE_ROOT_STATE',
      'The current readiness root state differs from the reviewed expectation.',
      false, false, '[]'::jsonb, '[]'::jsonb,
      v_set.readiness_status, v_set.current_evaluation_id,
      v_evaluation.evaluation_version
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'expected_current_evaluation_id')
      is distinct from v_set.current_evaluation_id
    or atlas_core.pa_05b_safe_bigint(request ->> 'expected_current_evaluation_version')
      is distinct from v_evaluation.evaluation_version
  then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'STALE_CURRENT_EVALUATION',
      'The current readiness evaluation differs from the reviewed expectation.',
      false, false, '[]'::jsonb, '[]'::jsonb,
      v_set.readiness_status, v_set.current_evaluation_id,
      v_evaluation.evaluation_version
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;
  if v_set.readiness_status not in ('READY', 'NEED_GENERATION_REQUESTED') then
    v_error := atlas_core.rmvp_03b_error(
      request, v_name, 'INVALID_LIFECYCLE_STATE',
      'The current readiness state cannot be invalidated.'
    );
    return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
  end if;

  if v_reason = 'UPSTREAM_SOURCE_CHANGED' then
    if v_evaluation.weekly_menu_id is not null then
      perform 1 from atlas_planning.weekly_menus menu
      where menu.weekly_menu_id = v_evaluation.weekly_menu_id for update;
    end if;
    if v_evaluation.attendance_batch_id is not null then
      perform 1 from atlas_planning.attendance_batches batch
      where batch.attendance_batch_id = v_evaluation.attendance_batch_id for update;
    end if;
    if v_evaluation.pantry_need_batch_id is not null then
      perform 1 from atlas_planning.pantry_need_batches batch
      where batch.pantry_need_batch_id = v_evaluation.pantry_need_batch_id for update;
    end if;
    v_stale_types := atlas_core.rmvp_03b_stale_source_types(
      v_evaluation.planning_input_evaluation_id, v_start, v_end
    );
    if pg_catalog.jsonb_array_length(v_stale_types) = 0 then
      v_error := atlas_core.rmvp_03b_error(
        request, v_name, 'INVALIDATION_REASON_MISMATCH',
        'No bound upstream source change was detected.'
      );
      return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
    end if;
  elsif v_reason = 'NEED_GENERATION_REQUEST_WITHDRAWN' then
    if v_set.readiness_status <> 'NEED_GENERATION_REQUESTED' then
      v_error := atlas_core.rmvp_03b_error(
        request, v_name, 'INVALIDATION_REASON_MISMATCH',
        'Only a requested handoff can be withdrawn.'
      );
      return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
    end if;
    if exists (
      select 1 from atlas_planning.need_generation_runs run
      where run.planning_input_set_id = v_set_id
        and run.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id
    ) then
      v_error := atlas_core.rmvp_03b_error(
        request, v_name, 'NEED_GENERATION_HANDOFF_ALREADY_CONSUMED',
        'The handoff has already been consumed by a Need Generation run.'
      );
      return atlas_core.rmvp_03b_finish_error(v_receipt_id, v_error);
    end if;
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'readiness_status', v_set.readiness_status,
    'planning_input_evaluation_id', v_evaluation.planning_input_evaluation_id,
    'current_evaluation_version', v_evaluation.evaluation_version
  );
  update atlas_planning.planning_input_sets input_set
  set readiness_status = 'INVALIDATED',
    updated_at = pg_catalog.transaction_timestamp()
  where input_set.planning_input_set_id = v_set_id;
  v_after := v_before || pg_catalog.jsonb_build_object(
    'readiness_status', 'INVALIDATED',
    'stale_source_types', coalesce(v_stale_types, '[]'::jsonb)
  );
  v_selection := pg_catalog.jsonb_build_object(
    'weekly_menu', case when v_evaluation.weekly_menu_id is null then null else pg_catalog.jsonb_build_object(
      'weekly_menu_id', v_evaluation.weekly_menu_id,
      'weekly_menu_version', v_evaluation.weekly_menu_version,
      'weekly_menu_approval_snapshot_id', v_evaluation.weekly_menu_approval_snapshot_id
    ) end,
    'attendance', case when v_evaluation.attendance_batch_id is null then null else pg_catalog.jsonb_build_object(
      'attendance_batch_id', v_evaluation.attendance_batch_id,
      'attendance_version', v_evaluation.attendance_version,
      'attendance_approval_snapshot_id', v_evaluation.attendance_approval_snapshot_id
    ) end,
    'pantry', case when v_evaluation.pantry_need_batch_id is null then null else pg_catalog.jsonb_build_object(
      'pantry_need_batch_id', v_evaluation.pantry_need_batch_id,
      'pantry_need_batch_version', v_evaluation.pantry_need_batch_version,
      'pantry_need_approval_snapshot_id', v_evaluation.pantry_need_approval_snapshot_id
    ) end
  );
  return atlas_core.rmvp_03b_finish_success(
    request, v_actor_id, v_receipt_id,
    'PlanningInputReadinessInvalidated', v_set_id,
    v_evaluation.planning_input_evaluation_id,
    v_evaluation.evaluation_version, v_before, v_after,
    'The current Planning Input Readiness decision was invalidated.',
    v_selection
  );
exception when serialization_failure or deadlock_detected then
  return atlas_core.rmvp_03b_error(
    request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Readiness data is being updated. Retry the exact unchanged request.',
    false, true
  );
when others then
  return atlas_core.rmvp_03b_error(
    request, v_name, 'INVARIANT_VIOLATION',
    'The readiness invalidation could not be completed safely.'
  );
end;
$$;

grant select on
  atlas_planning.planning_input_sets,
  atlas_planning.planning_input_evaluations,
  atlas_planning.planning_input_evaluation_issues,
  atlas_planning.need_generation_runs
to atlas_read_runtime, atlas_planning_command_runtime;

grant insert on
  atlas_planning.planning_input_sets,
  atlas_planning.planning_input_evaluations,
  atlas_planning.planning_input_evaluation_issues
to atlas_planning_command_runtime;

grant update on atlas_planning.planning_input_sets
to atlas_planning_command_runtime;

grant select on
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_planning_command_runtime;

create policy rmvp_03b_read_input_sets_select
on atlas_planning.planning_input_sets
for select to atlas_read_runtime using (true);
create policy rmvp_03b_read_evaluations_select
on atlas_planning.planning_input_evaluations
for select to atlas_read_runtime using (true);
create policy rmvp_03b_read_issues_select
on atlas_planning.planning_input_evaluation_issues
for select to atlas_read_runtime using (true);
create policy rmvp_03b_read_runs_select
on atlas_planning.need_generation_runs
for select to atlas_read_runtime using (true);

create policy rmvp_03b_command_input_sets_select
on atlas_planning.planning_input_sets
for select to atlas_planning_command_runtime using (true);
create policy rmvp_03b_command_evaluations_select
on atlas_planning.planning_input_evaluations
for select to atlas_planning_command_runtime using (true);
create policy rmvp_03b_command_issues_select
on atlas_planning.planning_input_evaluation_issues
for select to atlas_planning_command_runtime using (true);
create policy rmvp_03b_command_runs_select
on atlas_planning.need_generation_runs
for select to atlas_planning_command_runtime using (true);
create policy rmvp_03b_command_input_sets_insert
on atlas_planning.planning_input_sets
for insert to atlas_planning_command_runtime with check (true);
create policy rmvp_03b_command_input_sets_update
on atlas_planning.planning_input_sets
for update to atlas_planning_command_runtime using (true) with check (true);
create policy rmvp_03b_command_evaluations_insert
on atlas_planning.planning_input_evaluations
for insert to atlas_planning_command_runtime with check (true);
create policy rmvp_03b_command_issues_insert
on atlas_planning.planning_input_evaluation_issues
for insert to atlas_planning_command_runtime with check (true);

revoke execute on function
  atlas_core.rmvp_03b_safe_date(text),
  atlas_core.rmvp_03b_normalize_text(text),
  atlas_core.rmvp_03b_sha256(jsonb),
  atlas_core.rmvp_03b_error(
    jsonb, text, text, text, boolean, boolean, jsonb, jsonb,
    text, uuid, bigint
  ),
  atlas_core.rmvp_03b_authorize_global(jsonb, text, text, boolean),
  atlas_core.rmvp_03b_validate_read(jsonb, text),
  atlas_core.rmvp_03b_validate_command(jsonb, text),
  atlas_core.rmvp_03b_candidate_is_well_formed(text, jsonb),
  atlas_core.rmvp_03b_source_evidence(text, date, date, jsonb),
  atlas_core.rmvp_03b_calculate_issues(date, date, jsonb, jsonb, jsonb),
  atlas_core.rmvp_03b_bindings_current(uuid, date, date),
  atlas_core.rmvp_03b_stale_source_types(uuid, date, date),
  atlas_core.rmvp_03b_all_history_items(uuid),
  atlas_core.rmvp_03b_history_page(uuid, date, date, integer, text),
  atlas_core.rmvp_03b_workbench_payload(date, date, jsonb, integer, text),
  atlas_core.rmvp_03b_begin_receipt(jsonb, uuid, text, text),
  atlas_core.rmvp_03b_prepare_command(jsonb, text, text),
  atlas_core.rmvp_03b_finish_error(uuid, jsonb),
  atlas_core.rmvp_03b_record_change(
    jsonb, uuid, uuid, text, uuid, jsonb, jsonb
  ),
  atlas_core.rmvp_03b_finish_success(
    jsonb, uuid, uuid, text, uuid, uuid, bigint,
    jsonb, jsonb, text, jsonb
  )
from public, anon, authenticated, service_role;

grant execute on function
  atlas_core.rmvp_03b_safe_date(text),
  atlas_core.rmvp_03b_error(
    jsonb, text, text, text, boolean, boolean, jsonb, jsonb,
    text, uuid, bigint
  ),
  atlas_core.rmvp_03b_authorize_global(jsonb, text, text, boolean),
  atlas_core.rmvp_03b_validate_read(jsonb, text),
  atlas_core.rmvp_03b_candidate_is_well_formed(text, jsonb),
  atlas_core.rmvp_03b_source_evidence(text, date, date, jsonb),
  atlas_core.rmvp_03b_bindings_current(uuid, date, date),
  atlas_core.rmvp_03b_stale_source_types(uuid, date, date),
  atlas_core.rmvp_03b_all_history_items(uuid),
  atlas_core.rmvp_03b_history_page(uuid, date, date, integer, text),
  atlas_core.rmvp_03b_workbench_payload(date, date, jsonb, integer, text)
to atlas_read_runtime;

grant execute on function
  atlas_core.rmvp_03b_safe_date(text),
  atlas_core.rmvp_03b_normalize_text(text),
  atlas_core.rmvp_03b_sha256(jsonb),
  atlas_core.rmvp_03b_error(
    jsonb, text, text, text, boolean, boolean, jsonb, jsonb,
    text, uuid, bigint
  ),
  atlas_core.rmvp_03b_authorize_global(jsonb, text, text, boolean),
  atlas_core.rmvp_03b_validate_command(jsonb, text),
  atlas_core.rmvp_03b_candidate_is_well_formed(text, jsonb),
  atlas_core.rmvp_03b_source_evidence(text, date, date, jsonb),
  atlas_core.rmvp_03b_calculate_issues(date, date, jsonb, jsonb, jsonb),
  atlas_core.rmvp_03b_bindings_current(uuid, date, date),
  atlas_core.rmvp_03b_stale_source_types(uuid, date, date),
  atlas_core.rmvp_03b_all_history_items(uuid),
  atlas_core.rmvp_03b_history_page(uuid, date, date, integer, text),
  atlas_core.rmvp_03b_workbench_payload(date, date, jsonb, integer, text),
  atlas_core.rmvp_03b_begin_receipt(jsonb, uuid, text, text),
  atlas_core.rmvp_03b_prepare_command(jsonb, text, text),
  atlas_core.rmvp_03b_finish_error(uuid, jsonb),
  atlas_core.rmvp_03b_record_change(
    jsonb, uuid, uuid, text, uuid, jsonb, jsonb
  ),
  atlas_core.rmvp_03b_finish_success(
    jsonb, uuid, uuid, text, uuid, uuid, bigint,
    jsonb, jsonb, text, jsonb
  )
to atlas_planning_command_runtime;

reset role;

grant atlas_planning_command_runtime, atlas_read_runtime
to postgres with set true;
grant create on schema atlas_api
to atlas_planning_command_runtime, atlas_read_runtime;

alter function atlas_api.get_planning_input_readiness_workbench(jsonb)
owner to atlas_read_runtime;
alter function atlas_api.evaluate_planning_input_readiness(jsonb)
owner to atlas_planning_command_runtime;
alter function atlas_api.request_planning_input_need_generation(jsonb)
owner to atlas_planning_command_runtime;
alter function atlas_api.invalidate_planning_input_readiness(jsonb)
owner to atlas_planning_command_runtime;

revoke create on schema atlas_api
from atlas_planning_command_runtime, atlas_read_runtime;

revoke execute on function
  atlas_api.get_planning_input_readiness_workbench(jsonb),
  atlas_api.evaluate_planning_input_readiness(jsonb),
  atlas_api.request_planning_input_need_generation(jsonb),
  atlas_api.invalidate_planning_input_readiness(jsonb)
from public, anon, authenticated, service_role;

grant execute on function
  atlas_api.get_planning_input_readiness_workbench(jsonb),
  atlas_api.evaluate_planning_input_readiness(jsonb),
  atlas_api.request_planning_input_need_generation(jsonb),
  atlas_api.invalidate_planning_input_readiness(jsonb)
to authenticated;

comment on function atlas_api.get_planning_input_readiness_workbench(jsonb)
is 'RMVP-03B authorized exact-period three-source readiness evidence, decision, action, and immutable combined-history read.';
comment on function atlas_api.evaluate_planning_input_readiness(jsonb)
is 'RMVP-03B atomic Planning Input Readiness evaluation using exact current approved source triples and backend-derived issues.';
comment on function atlas_api.request_planning_input_need_generation(jsonb)
is 'RMVP-03B handoff-only READY to NEED_GENERATION_REQUESTED command; creates no Need Generation run or quantity.';
comment on function atlas_api.invalidate_planning_input_readiness(jsonb)
is 'RMVP-03B reasoned readiness invalidation retaining immutable evaluation/source evidence and never mutating a Need Generation run.';
