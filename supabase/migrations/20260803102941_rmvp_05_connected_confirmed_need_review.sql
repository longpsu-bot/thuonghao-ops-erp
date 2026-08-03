-- RMVP-05: connected Confirmed Need review and quantity confirmation.
--
-- This migration exposes one shaped review, one write-free canonical preview,
-- and one idempotent confirmation command over the existing H0B1/H1A/H1B1
-- structures. It adds no business relation, view, lifecycle state, scope kind,
-- sequence, trigger, downstream fact, or production policy seed.

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_roles
    where rolname = 'atlas_confirmed_need_review_runtime'
  ) then
    create role atlas_confirmed_need_review_runtime nologin noinherit;
  end if;
end
$$;

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values
  (
    'confirmed_need_review.read',
    'Read Confirmed Need review',
    'PLANNING',
    'ACTIVE'
  ),
  (
    'confirmed_need_quantities.preview',
    'Preview Confirmed Need quantities',
    'PLANNING',
    'ACTIVE'
  ),
  (
    'confirmed_need_quantities.confirm',
    'Confirm Confirmed Need quantities',
    'PLANNING',
    'ACTIVE'
  );

set role atlas_owner;

create function atlas_core.rmvp_05_error(
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
      'contract_version', 'RMVP-05.v1',
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
      'command_id', case when is_read then null else request ->> 'command_id' end,
      'write_certainty', case when is_read then 'NO_WRITE' else 'NO_BUSINESS_WRITE' end,
      'local_draft_may_be_preserved', true,
      'exact_retry_safe', retryable,
      'refresh_read', 'get_confirmed_need_review'
    )
  );
$$;

create function atlas_core.rmvp_05_authorize_global(
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
        'contract_version', 'RMVP-05.v1',
        case when is_read then 'read_name' else 'command_name' end,
          operation_name,
        'write_certainty', case when is_read then 'NO_WRITE' else 'NO_BUSINESS_WRITE' end,
        'local_draft_may_be_preserved', true,
        'refresh_read', 'get_confirmed_need_review'
      )
    );
  end if;

  if v_context ->> 'actor_type' is distinct from 'HUMAN' then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.rmvp_05_error(
        request,
        operation_name,
        'HUMAN_ACTOR_REQUIRED',
        'An active human Planning operator is required.',
        is_read
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
        'contract_version', 'RMVP-05.v1',
        case when is_read then 'read_name' else 'command_name' end,
          operation_name,
        'write_certainty', case when is_read then 'NO_WRITE' else 'NO_BUSINESS_WRITE' end,
        'local_draft_may_be_preserved', true,
        'refresh_read', 'get_confirmed_need_review'
      )
    );
  end if;

  return pg_catalog.jsonb_build_object('actor_id', v_actor_id);
end;
$$;

create function atlas_core.rmvp_05_validate_read(
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
  v_payload jsonb;
  v_filters jsonb;
  v_limit bigint;
  v_offset bigint;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_05_error(
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
        'field', 'request', 'message', 'Provide exactly the RMVP-05 read envelope.'
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-05.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use RMVP-05.v1.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'requested_by_auth_subject', 'message', 'A valid UUID is required.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'correlation_id', 'message', 'A valid UUID is required.')
    );
  end if;

  if pg_catalog.jsonb_typeof(request -> 'payload') is distinct from 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'A JSON object is required.')
    );
  else
    v_payload := request -> 'payload';
    if v_payload - array[
      'confirmed_need_batch_id', 'filters', 'line_offset', 'line_limit'
    ] <> '{}'::jsonb or not (v_payload ? 'confirmed_need_batch_id')
      or atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id') is null
    then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'The review payload is invalid.')
      );
    end if;

    v_offset := coalesce(atlas_core.pa_05b_safe_bigint(v_payload ->> 'line_offset'), 0);
    v_limit := coalesce(atlas_core.pa_05b_safe_bigint(v_payload ->> 'line_limit'), 100);
    if v_offset < 0 then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.line_offset', 'message', 'Offset must be zero or greater.')
      );
    end if;
    if v_limit < 1 or v_limit > 250 then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.line_limit', 'message', 'Limit must be between 1 and 250.')
      );
    end if;

    if v_payload ? 'filters' and v_payload -> 'filters' <> 'null'::jsonb then
      if pg_catalog.jsonb_typeof(v_payload -> 'filters') <> 'object' then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.filters', 'message', 'Filters must be an object.')
        );
      else
        v_filters := v_payload -> 'filters';
        if v_filters - array[
          'service_date', 'school_id', 'delivery_location_id', 'ingredient_id', 'decision_state'
        ] <> '{}'::jsonb
          or (v_filters ? 'service_date' and v_filters -> 'service_date' <> 'null'::jsonb
            and atlas_core.rmvp_04_safe_date(v_filters ->> 'service_date') is null)
          or (v_filters ? 'school_id' and v_filters -> 'school_id' <> 'null'::jsonb
            and atlas_core.pa_05b_safe_uuid(v_filters ->> 'school_id') is null)
          or (v_filters ? 'delivery_location_id' and v_filters -> 'delivery_location_id' <> 'null'::jsonb
            and atlas_core.pa_05b_safe_uuid(v_filters ->> 'delivery_location_id') is null)
          or (v_filters ? 'ingredient_id' and v_filters -> 'ingredient_id' <> 'null'::jsonb
            and atlas_core.pa_05b_safe_uuid(v_filters ->> 'ingredient_id') is null)
          or (v_filters ? 'decision_state' and v_filters -> 'decision_state' <> 'null'::jsonb
            and v_filters ->> 'decision_state' not in ('UNREVIEWED', 'CONFIRMED'))
        then
          v_errors := v_errors || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('field', 'payload.filters', 'message', 'One or more filters are invalid.')
          );
        end if;
      end if;
    end if;
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_05_error(
      request, read_name, 'VALIDATION_FAILED',
      'The Confirmed Need review request is invalid.', true, false, v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_core.rmvp_05_validate_preview(
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
  v_payload jsonb;
  v_lines jsonb;
  v_line jsonb;
  v_quantity_type text;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_05_error(
      coalesce(request, '{}'::jsonb), read_name, 'VALIDATION_FAILED',
      'The preview request must be a JSON object.', true
    );
  end if;
  if request - array[
    'contract_version', 'requested_by_auth_subject', 'correlation_id', 'payload'
  ] <> '{}'::jsonb or not (request ?& array[
    'contract_version', 'requested_by_auth_subject', 'correlation_id', 'payload'
  ]) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'request', 'message', 'Provide exactly the RMVP-05 read envelope.')
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-05.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use RMVP-05.v1.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null
    or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'request.identity', 'message', 'Valid subject and correlation UUIDs are required.')
    );
  end if;

  if pg_catalog.jsonb_typeof(request -> 'payload') is distinct from 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'A JSON object is required.')
    );
  else
    v_payload := request -> 'payload';
    if v_payload - array[
      'confirmed_need_batch_id', 'expected_batch_version', 'lines'
    ] <> '{}'::jsonb or not (v_payload ?& array[
      'confirmed_need_batch_id', 'expected_batch_version', 'lines'
    ]) or atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id') is null
      or coalesce(atlas_core.pa_05b_safe_bigint(v_payload ->> 'expected_batch_version'), 0) < 1
    then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Batch identity and positive expected version are required.')
      );
    end if;
    v_lines := v_payload -> 'lines';
    if pg_catalog.jsonb_typeof(v_lines) is distinct from 'array'
      or pg_catalog.jsonb_array_length(coalesce(v_lines, '[]'::jsonb)) not between 1 and 250
    then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Select between 1 and 250 lines.')
      );
    else
      if (
        select count(*) <> count(distinct value ->> 'confirmed_need_line_id')
        from pg_catalog.jsonb_array_elements(v_lines)
      ) then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Stable lines must be unique.')
        );
      end if;
      for v_line in select value from pg_catalog.jsonb_array_elements(v_lines)
      loop
        v_quantity_type := pg_catalog.jsonb_typeof(v_line -> 'proposed_confirmed_quantity');
        if pg_catalog.jsonb_typeof(v_line) is distinct from 'object'
          or v_line - array[
            'confirmed_need_line_id', 'expected_current_revision_id',
            'expected_current_decision_id', 'proposed_confirmed_quantity',
            'reason_code', 'reason_note'
          ] <> '{}'::jsonb
          or not (v_line ?& array[
            'confirmed_need_line_id', 'expected_current_revision_id',
            'expected_current_decision_id', 'proposed_confirmed_quantity',
            'reason_code', 'reason_note'
          ])
          or atlas_core.pa_05b_safe_uuid(v_line ->> 'confirmed_need_line_id') is null
          or atlas_core.pa_05b_safe_uuid(v_line ->> 'expected_current_revision_id') is null
          or (v_line -> 'expected_current_decision_id' <> 'null'::jsonb
            and atlas_core.pa_05b_safe_uuid(v_line ->> 'expected_current_decision_id') is null)
          or v_quantity_type not in ('number', 'string')
          or v_line ->> 'reason_code' not in (
            'PROPOSAL_ACCEPTED', 'PLANNING_STEP_ADJUSTMENT',
            'OPERATIONAL_QUANTITY_ADJUSTMENT', 'OTHER'
          )
          or (v_line -> 'reason_note' <> 'null'::jsonb
            and (pg_catalog.jsonb_typeof(v_line -> 'reason_note') <> 'string'
              or pg_catalog.char_length(pg_catalog.btrim(v_line ->> 'reason_note')) > 500))
        then
          v_errors := v_errors || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'field', 'payload.lines',
              'line_id', v_line ->> 'confirmed_need_line_id',
              'message', 'A selected line contains invalid fields.'
            )
          );
        end if;
      end loop;
    end if;
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_05_error(
      request, read_name, 'VALIDATION_FAILED',
      'The Confirmed Need preview request is invalid.', true, false, v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_core.rmvp_05_validate_command(
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
  v_preview_request jsonb;
  v_preview_error jsonb;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_05_error(
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
      pg_catalog.jsonb_build_object('field', 'request', 'message', 'Provide exactly the Atlas write envelope.')
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-05.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use RMVP-05.v1.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
    or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
    or atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null
    or atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at') is null
    or coalesce(atlas_core.pa_05b_safe_bigint(request ->> 'expected_version'), 0) < 1
    or nullif(pg_catalog.btrim(request ->> 'idempotency_key'), '') is null
    or pg_catalog.char_length(request ->> 'idempotency_key') > 200
    or request ->> 'reason_code' is distinct from 'CONFIRMED_NEED_QUANTITIES_CONFIRMED'
    or request -> 'reason_note' <> 'null'::jsonb
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'request', 'message', 'The command identity, version, time, or reason is invalid.')
    );
  end if;

  v_payload := request -> 'payload';
  if pg_catalog.jsonb_typeof(v_payload) is distinct from 'object'
    or v_payload - array['confirmed_need_batch_id', 'preview_hash', 'lines'] <> '{}'::jsonb
    or not (v_payload ?& array['confirmed_need_batch_id', 'preview_hash', 'lines'])
    or coalesce(v_payload ->> 'preview_hash', '') !~ '^[0-9a-f]{64}$'
  then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'The confirmation payload or preview hash is invalid.')
    );
  else
    v_preview_request := pg_catalog.jsonb_build_object(
      'contract_version', 'RMVP-05.v1',
      'requested_by_auth_subject', request -> 'requested_by_auth_subject',
      'correlation_id', request -> 'correlation_id',
      'payload', pg_catalog.jsonb_build_object(
        'confirmed_need_batch_id', v_payload -> 'confirmed_need_batch_id',
        'expected_batch_version', request -> 'expected_version',
        'lines', v_payload -> 'lines'
      )
    );
    v_preview_error := atlas_core.rmvp_05_validate_preview(
      v_preview_request, 'preview_confirmed_need_confirmation'
    );
    if v_preview_error is not null then
      v_errors := v_errors || coalesce(v_preview_error -> 'field_errors', '[]'::jsonb);
    end if;
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_05_error(
      request, command_name, 'VALIDATION_FAILED',
      'The Confirmed Need confirmation command is invalid.', false, false, v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_core.rmvp_05_workbench_payload(
  batch_id uuid,
  filters jsonb default '{}'::jsonb,
  line_offset integer default 0,
  line_limit integer default 100
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with batch as (
    select b.*, r.run_status
    from atlas_planning.confirmed_need_batches b
    left join atlas_planning.need_generation_runs r
      on r.need_generation_run_id = b.current_need_generation_run_id
    where b.confirmed_need_batch_id = batch_id
      and b.source_kind = 'NEED_GENERATION'
  ),
  current_lines as (
    select
      l.*,
      revision.confirmed_need_line_revision_id,
      revision.revision_number,
      revision.theoretical_quantity,
      revision.confirmed_quantity as proposed_confirmed_quantity,
      revision.need_generation_run_id,
      revision.need_generation_run_version,
      revision.need_generation_release_snapshot_id,
      customer.customer_name,
      school.school_name,
      location.location_name as delivery_location_name,
      ingredient.ingredient_name,
      unit.unit_code,
      unit.unit_name,
      decision.confirmed_need_line_decision_id,
      decision.decision_number,
      decision.decision_kind,
      decision.confirmed_quantity_after,
      policy.policy_count,
      policy.planning_quantity_policy_id,
      policy.planning_quantity_policy_revision_id,
      policy.policy_revision_number,
      policy.planning_step,
      policy.policy_revision_status,
      policy.effective_from,
      policy.effective_to,
      membership.membership_count,
      (
        b.run_status is distinct from 'RELEASED_FOR_CONFIRMATION'
        or revision.need_generation_run_id is distinct from b.current_need_generation_run_id
        or revision.need_generation_run_version is distinct from b.current_need_generation_run_version
        or revision.need_generation_release_snapshot_id is distinct from b.current_need_generation_release_snapshot_id
        or membership.membership_count = 0
      ) as source_stale
    from batch b
    join atlas_planning.confirmed_need_lines l
      on l.confirmed_need_batch_id = b.confirmed_need_batch_id
     and l.source_kind = 'NEED_GENERATION'
    join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_id = l.confirmed_need_line_id
     and revision.is_current
    join atlas_admin.customers customer on customer.customer_id = l.customer_id
    join atlas_admin.schools school on school.school_id = l.school_id
    join atlas_admin.delivery_locations location
      on location.delivery_location_id = l.delivery_location_id
    join atlas_admin.ingredients ingredient on ingredient.ingredient_id = l.ingredient_id
    join atlas_admin.units unit on unit.unit_id = l.controlled_unit_id
    left join atlas_planning.confirmed_need_line_decisions decision
      on decision.confirmed_need_line_decision_id = l.current_confirmed_need_line_decision_id
    left join lateral (
      select
        count(*)::integer as policy_count,
        (array_agg(p.planning_quantity_policy_id order by p.effective_from desc, p.planning_quantity_policy_revision_id))[1]
          as planning_quantity_policy_id,
        (array_agg(p.planning_quantity_policy_revision_id order by p.effective_from desc, p.planning_quantity_policy_revision_id))[1]
          as planning_quantity_policy_revision_id,
        (array_agg(p.revision_number order by p.effective_from desc, p.planning_quantity_policy_revision_id))[1]
          as policy_revision_number,
        (array_agg(p.planning_step order by p.effective_from desc, p.planning_quantity_policy_revision_id))[1]
          as planning_step,
        (array_agg(p.policy_revision_status order by p.effective_from desc, p.planning_quantity_policy_revision_id))[1]
          as policy_revision_status,
        (array_agg(p.effective_from order by p.effective_from desc, p.planning_quantity_policy_revision_id))[1]
          as effective_from,
        (array_agg(p.effective_to order by p.effective_from desc, p.planning_quantity_policy_revision_id))[1]
          as effective_to
      from atlas_planning.planning_quantity_policy_revisions p
      where p.unit_id = l.controlled_unit_id
        and p.policy_revision_status in ('ACTIVE', 'RETIRED')
        and p.effective_from <= l.service_date
        and (p.effective_to is null or l.service_date < p.effective_to)
    ) policy on true
    left join lateral (
      select count(*)::integer as membership_count
      from atlas_planning.confirmed_need_line_revision_contributions c
      where c.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
    ) membership on true
  ),
  filtered as (
    select *
    from current_lines line
    where (not (filters ? 'service_date') or filters -> 'service_date' = 'null'::jsonb
        or line.service_date = atlas_core.rmvp_04_safe_date(filters ->> 'service_date'))
      and (not (filters ? 'school_id') or filters -> 'school_id' = 'null'::jsonb
        or line.school_id = atlas_core.pa_05b_safe_uuid(filters ->> 'school_id'))
      and (not (filters ? 'delivery_location_id') or filters -> 'delivery_location_id' = 'null'::jsonb
        or line.delivery_location_id = atlas_core.pa_05b_safe_uuid(filters ->> 'delivery_location_id'))
      and (not (filters ? 'ingredient_id') or filters -> 'ingredient_id' = 'null'::jsonb
        or line.ingredient_id = atlas_core.pa_05b_safe_uuid(filters ->> 'ingredient_id'))
      and (not (filters ? 'decision_state') or filters -> 'decision_state' = 'null'::jsonb
        or (filters ->> 'decision_state' = 'UNREVIEWED' and line.confirmed_need_line_decision_id is null)
        or (filters ->> 'decision_state' = 'CONFIRMED' and line.confirmed_need_line_decision_id is not null))
  ),
  page as (
    select *
    from filtered
    order by service_date, school_name, delivery_location_name,
      ingredient_name, confirmed_need_line_id
    offset line_offset
    limit line_limit
  ),
  counts as (
    select
      count(*)::integer as line_count,
      count(*) filter (where confirmed_need_line_decision_id is null)::integer as unreviewed_count,
      count(*) filter (where confirmed_need_line_decision_id is not null)::integer as confirmed_count,
      count(*) filter (where decision_kind = 'ADJUSTED_QUANTITY_CONFIRMED')::integer as adjusted_count,
      count(*) filter (where source_stale)::integer as source_stale_count,
      count(*) filter (where policy_count <> 1)::integer as policy_blocker_count
    from current_lines
  )
  select case
    when not exists (select 1 from batch) then null
    else (
      select pg_catalog.jsonb_build_object(
        'confirmed_need_batch_id', b.confirmed_need_batch_id,
        'source_kind', b.source_kind,
        'batch_status', b.batch_status,
        'batch_version', b.version,
        'need_generation_source', pg_catalog.jsonb_build_object(
          'run_id', b.current_need_generation_run_id,
          'run_version', b.current_need_generation_run_version,
          'release_snapshot_id', b.current_need_generation_release_snapshot_id
        ),
        'service_period', pg_catalog.jsonb_build_object(
          'period_start', b.period_start,
          'period_end', b.period_end
        ),
        'line_counts', pg_catalog.jsonb_build_object(
          'total', c.line_count,
          'unreviewed', c.unreviewed_count,
          'confirmed', c.confirmed_count,
          'adjusted', c.adjusted_count
        ),
        'blockers',
          (case when b.batch_status not in ('DRAFT_REVIEW', 'REOPENED')
            then pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
              'code', 'CONFIRMED_NEED_BATCH_NOT_REVIEWABLE',
              'message', 'The batch is not in a reviewable lifecycle state.'
            )) else '[]'::jsonb end)
          || (case when c.source_stale_count > 0
            then pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
              'code', 'STALE_CONFIRMED_NEED_LINE',
              'message', 'One or more current lines no longer match the exact released source.'
            )) else '[]'::jsonb end)
          || (case when c.policy_blocker_count > 0
            then pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
              'code', 'MISSING_OR_AMBIGUOUS_PLANNING_QUANTITY_POLICY',
              'message', 'Every line requires exactly one effective Planning quantity policy.'
            )) else '[]'::jsonb end),
        'warnings', '[]'::jsonb,
        'allowed_actions', pg_catalog.jsonb_build_object(
          'preview_confirmation', b.batch_status in ('DRAFT_REVIEW', 'REOPENED')
            and c.line_count > 0 and c.source_stale_count = 0 and c.policy_blocker_count = 0,
          'confirm_quantities', b.batch_status in ('DRAFT_REVIEW', 'REOPENED')
            and c.line_count > 0 and c.source_stale_count = 0 and c.policy_blocker_count = 0
        ),
        'disabled_reasons', pg_catalog.jsonb_build_object(
          'preview_confirmation', case
            when b.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then 'Batch is not reviewable.'
            when c.line_count = 0 then 'Batch contains no current operational line.'
            when c.source_stale_count > 0 then 'Refresh stale source evidence.'
            when c.policy_blocker_count > 0 then 'Resolve missing or ambiguous Planning quantity policy.'
            else null end,
          'confirm_quantities', case
            when b.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then 'Batch is not reviewable.'
            when c.line_count = 0 then 'Batch contains no current operational line.'
            when c.source_stale_count > 0 then 'Refresh stale source evidence.'
            when c.policy_blocker_count > 0 then 'Resolve missing or ambiguous Planning quantity policy.'
            else null end
        ),
        'pagination', pg_catalog.jsonb_build_object(
          'offset', line_offset,
          'limit', line_limit,
          'total_lines', (select count(*) from filtered),
          'has_more', line_offset + line_limit < (select count(*) from filtered)
        ),
        'lines', coalesce((
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'confirmed_need_line_id', line.confirmed_need_line_id,
              'current_revision_id', line.confirmed_need_line_revision_id,
              'current_revision_number', line.revision_number,
              'service_date', line.service_date,
              'customer', pg_catalog.jsonb_build_object('id', line.customer_id, 'name', line.customer_name),
              'school', pg_catalog.jsonb_build_object('id', line.school_id, 'name', line.school_name),
              'delivery_location', pg_catalog.jsonb_build_object('id', line.delivery_location_id, 'name', line.delivery_location_name),
              'ingredient', pg_catalog.jsonb_build_object('id', line.ingredient_id, 'name', line.ingredient_name),
              'controlled_unit', pg_catalog.jsonb_build_object('id', line.controlled_unit_id, 'code', line.unit_code, 'name', line.unit_name),
              'theoretical_quantity', line.theoretical_quantity::text,
              'proposed_confirmed_quantity', line.proposed_confirmed_quantity::text,
              'current_decision_id', line.confirmed_need_line_decision_id,
              'current_decision_number', line.decision_number,
              'current_decision_kind', line.decision_kind,
              'confirmed_quantity_after', line.confirmed_quantity_after::text,
              'effective_policy', case when line.policy_count = 1 then pg_catalog.jsonb_build_object(
                'root_id', line.planning_quantity_policy_id,
                'revision_id', line.planning_quantity_policy_revision_id,
                'revision_number', line.policy_revision_number,
                'planning_step', line.planning_step::text,
                'status', line.policy_revision_status,
                'effective_from', line.effective_from,
                'effective_to', line.effective_to
              ) else null end,
              'source_membership_count', line.membership_count,
              'source_stale', line.source_stale,
              'blockers',
                (case when line.source_stale then pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                  'code', 'STALE_CONFIRMED_NEED_LINE', 'message', 'The current line source is stale.'
                )) else '[]'::jsonb end)
                || (case when line.policy_count = 0 then pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                  'code', 'MISSING_PLANNING_QUANTITY_POLICY', 'message', 'No effective Planning quantity policy exists.'
                )) when line.policy_count > 1 then pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                  'code', 'AMBIGUOUS_PLANNING_QUANTITY_POLICY', 'message', 'More than one effective Planning quantity policy exists.'
                )) else '[]'::jsonb end),
              'warnings', '[]'::jsonb,
              'decision_history', coalesce((
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'decision_id', history.confirmed_need_line_decision_id,
                    'decision_number', history.decision_number,
                    'predecessor_decision_id', history.predecessor_decision_id,
                    'decision_kind', history.decision_kind,
                    'revision_id', history.confirmed_need_line_revision_id,
                    'theoretical_quantity_before', history.theoretical_quantity_before::text,
                    'proposed_quantity_before', history.proposed_quantity_before::text,
                    'confirmed_quantity_after', history.confirmed_quantity_after::text,
                    'planning_tick_count', history.planning_tick_count::text,
                    'reason_code', history.reason_code,
                    'reason_note', history.reason_note,
                    'policy_revision_id', history.planning_quantity_policy_revision_id,
                    'decided_at', history.decided_at,
                    'batch_version', history.confirmed_need_batch_version
                  ) order by history.decision_number desc
                )
                from atlas_planning.confirmed_need_line_decisions history
                where history.confirmed_need_line_id = line.confirmed_need_line_id
              ), '[]'::jsonb)
            ) order by line.service_date, line.school_name, line.delivery_location_name,
              line.ingredient_name, line.confirmed_need_line_id
          )
          from page line
        ), '[]'::jsonb)
      )
      from batch b cross join counts c
    )
  end;
$$;

create function atlas_core.rmvp_05_canonical_preview(
  batch_id uuid,
  expected_batch_version bigint,
  requested_lines jsonb
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_item jsonb;
  v_line atlas_planning.confirmed_need_lines%rowtype;
  v_revision atlas_planning.confirmed_need_line_revisions%rowtype;
  v_decision atlas_planning.confirmed_need_line_decisions%rowtype;
  v_policy_count integer;
  v_policy atlas_planning.planning_quantity_policy_revisions%rowtype;
  v_quantity_text text;
  v_quantity numeric(20, 6);
  v_tick_count numeric(20, 0);
  v_reason text;
  v_note text;
  v_kind text;
  v_line_blockers jsonb;
  v_line_warnings jsonb;
  v_blockers jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_preview_lines jsonb := '[]'::jsonb;
  v_membership_count integer;
  v_membership_hash text;
  v_source_stale boolean;
  v_preview_hash text;
begin
  select * into v_batch
  from atlas_planning.confirmed_need_batches b
  where b.confirmed_need_batch_id = batch_id
    and b.source_kind = 'NEED_GENERATION';

  if not found then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'error_code', 'CONFIRMED_NEED_BATCH_NOT_FOUND',
      'blockers', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'CONFIRMED_NEED_BATCH_NOT_FOUND', 'field', 'confirmed_need_batch_id'
      )),
      'warnings', '[]'::jsonb,
      'ordered_preview_lines', '[]'::jsonb,
      'preview_hash', null,
      'write_certainty', 'NO_WRITE'
    );
  end if;

  if v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code', 'CONFIRMED_NEED_BATCH_NOT_REVIEWABLE',
      'field', 'confirmed_need_batch_id',
      'message', 'The batch is not in a reviewable lifecycle state.'
    ));
  end if;
  if v_batch.version <> expected_batch_version then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code', 'STALE_CONFIRMED_NEED_BATCH',
      'field', 'expected_batch_version',
      'expected', expected_batch_version,
      'actual', v_batch.version,
      'message', 'Refresh the Confirmed Need review before previewing again.'
    ));
  end if;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(requested_lines)
    order by value ->> 'confirmed_need_line_id'
  loop
    v_line_blockers := '[]'::jsonb;
    v_line_warnings := '[]'::jsonb;
    v_policy := null;
    v_decision := null;
    v_quantity := null;
    v_tick_count := null;
    v_quantity_text := v_item ->> 'proposed_confirmed_quantity';
    v_reason := v_item ->> 'reason_code';
    v_note := nullif(pg_catalog.btrim(v_item ->> 'reason_note'), '');

    select * into v_line
    from atlas_planning.confirmed_need_lines l
    where l.confirmed_need_line_id = atlas_core.pa_05b_safe_uuid(v_item ->> 'confirmed_need_line_id')
      and l.confirmed_need_batch_id = batch_id
      and l.source_kind = 'NEED_GENERATION';
    if not found then
      v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'STALE_CONFIRMED_NEED_LINE', 'field', 'confirmed_need_line_id',
        'message', 'The selected stable line is no longer current in this batch.'
      ));
      v_preview_lines := v_preview_lines || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'confirmed_need_line_id', v_item ->> 'confirmed_need_line_id',
        'blockers', v_line_blockers, 'warnings', v_line_warnings
      ));
      v_blockers := v_blockers || v_line_blockers;
      continue;
    end if;

    select * into strict v_revision
    from atlas_planning.confirmed_need_line_revisions r
    where r.confirmed_need_line_id = v_line.confirmed_need_line_id
      and r.is_current;

    if v_revision.confirmed_need_line_revision_id is distinct from
      atlas_core.pa_05b_safe_uuid(v_item ->> 'expected_current_revision_id')
    then
      v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'STALE_CONFIRMED_NEED_LINE', 'field', 'expected_current_revision_id',
        'message', 'The current quantity-bearing revision changed.'
      ));
    end if;

    if v_line.current_confirmed_need_line_decision_id is not null then
      select * into strict v_decision
      from atlas_planning.confirmed_need_line_decisions d
      where d.confirmed_need_line_decision_id = v_line.current_confirmed_need_line_decision_id;
    end if;
    if v_line.current_confirmed_need_line_decision_id is distinct from
      atlas_core.pa_05b_safe_uuid(v_item ->> 'expected_current_decision_id')
    then
      v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'STALE_CONFIRMED_NEED_DECISION', 'field', 'expected_current_decision_id',
        'message', 'The current decision evidence changed.'
      ));
    end if;

    select count(*)::integer into v_policy_count
    from atlas_planning.planning_quantity_policy_revisions p
    where p.unit_id = v_line.controlled_unit_id
      and p.policy_revision_status in ('ACTIVE', 'RETIRED')
      and p.effective_from <= v_line.service_date
      and (p.effective_to is null or v_line.service_date < p.effective_to);
    if v_policy_count = 0 then
      v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'MISSING_PLANNING_QUANTITY_POLICY', 'field', 'proposed_confirmed_quantity',
        'message', 'No eligible exact-Unit Planning quantity policy exists.'
      ));
    elsif v_policy_count > 1 then
      v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'AMBIGUOUS_PLANNING_QUANTITY_POLICY', 'field', 'proposed_confirmed_quantity',
        'message', 'More than one eligible exact-Unit Planning quantity policy exists.'
      ));
    else
      select * into strict v_policy
      from atlas_planning.planning_quantity_policy_revisions p
      where p.unit_id = v_line.controlled_unit_id
        and p.policy_revision_status in ('ACTIVE', 'RETIRED')
        and p.effective_from <= v_line.service_date
        and (p.effective_to is null or v_line.service_date < p.effective_to);
    end if;

    select count(*)::integer,
      pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
        coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'member_id', c.confirmed_need_line_revision_contribution_id,
          'release_line_id', c.need_generation_release_snapshot_line_id,
          'theoretical_line_id', c.theoretical_need_line_id,
          'source_quantity', c.source_theoretical_quantity::text,
          'controlled_quantity', c.controlled_contribution_quantity::text,
          'source_unit_id', c.source_unit_id,
          'controlled_unit_id', c.controlled_unit_id
        ) order by c.theoretical_need_line_id)::text, '[]'), 'UTF8')), 'hex')
    into v_membership_count, v_membership_hash
    from atlas_planning.confirmed_need_line_revision_contributions c
    where c.confirmed_need_line_revision_id = v_revision.confirmed_need_line_revision_id;

    v_source_stale := v_membership_count = 0
      or v_revision.need_generation_run_id is distinct from v_batch.current_need_generation_run_id
      or v_revision.need_generation_run_version is distinct from v_batch.current_need_generation_run_version
      or v_revision.need_generation_release_snapshot_id is distinct from v_batch.current_need_generation_release_snapshot_id
      or not exists (
        select 1
        from atlas_planning.need_generation_runs r
        where r.need_generation_run_id = v_batch.current_need_generation_run_id
          and r.version = v_batch.current_need_generation_run_version
          and r.run_status = 'RELEASED_FOR_CONFIRMATION'
      );
    if v_source_stale then
      v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'STALE_CONFIRMED_NEED_LINE', 'field', 'confirmed_need_line_id',
        'message', 'The current line no longer matches the exact released source.'
      ));
    end if;

    if v_quantity_text is null
      or v_quantity_text !~ '^(0|[1-9][0-9]{0,13})(\.[0-9]{1,6})?$'
    then
      v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'QUANTITY_NOT_REPRESENTABLE', 'field', 'proposed_confirmed_quantity',
        'message', 'Use a nonnegative decimal with at most fourteen integer and six fractional digits.'
      ));
    else
      begin
        v_quantity := v_quantity_text::numeric(20, 6);
      exception when others then
        v_quantity := null;
      end;
      if v_quantity is null then
        v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'code', 'QUANTITY_NOT_REPRESENTABLE', 'field', 'proposed_confirmed_quantity',
          'message', 'The quantity is outside the exact supported numeric range.'
        ));
      elsif v_policy_count = 1 and pg_catalog.mod(v_quantity, v_policy.planning_step) <> 0 then
        v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'code', 'QUANTITY_NOT_REPRESENTABLE', 'field', 'proposed_confirmed_quantity',
          'message', 'The quantity must equal a whole number of exact Planning steps.'
        ));
      elsif v_policy_count = 1 then
        v_tick_count := v_quantity / v_policy.planning_step;
      end if;
    end if;

    if v_quantity is not null and v_quantity = v_revision.confirmed_quantity then
      v_kind := 'UNCHANGED_PROPOSAL_ACCEPTED';
      if v_reason <> 'PROPOSAL_ACCEPTED' then
        v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'code', 'INVALID_DECISION_REASON', 'field', 'reason_code',
          'message', 'An unchanged proposal requires PROPOSAL_ACCEPTED.'
        ));
      end if;
      if v_line.current_confirmed_need_line_decision_id is null and v_note is not null then
        v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'code', 'INVALID_DECISION_REASON', 'field', 'reason_note',
          'message', 'The first unchanged acceptance must not include a note.'
        ));
      end if;
    else
      v_kind := 'ADJUSTED_QUANTITY_CONFIRMED';
      if v_reason not in (
        'PLANNING_STEP_ADJUSTMENT', 'OPERATIONAL_QUANTITY_ADJUSTMENT', 'OTHER'
      ) then
        v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'code', 'INVALID_DECISION_REASON', 'field', 'reason_code',
          'message', 'An adjusted quantity requires an allowed adjustment reason.'
        ));
      end if;
      if v_reason in ('OPERATIONAL_QUANTITY_ADJUSTMENT', 'OTHER') and v_note is null then
        v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'code', 'REASON_NOTE_REQUIRED', 'field', 'reason_note',
          'message', 'This adjustment reason requires a nonblank note.'
        ));
      end if;
    end if;
    if v_line.current_confirmed_need_line_decision_id is not null and v_note is null then
      v_line_blockers := v_line_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'REASON_NOTE_REQUIRED', 'field', 'reason_note',
        'message', 'Replacement decision evidence requires a nonblank correction note.'
      ));
    end if;
    if v_line.current_confirmed_need_line_decision_id is not null then
      v_line_warnings := v_line_warnings || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'DECISION_REPLACEMENT',
        'message', 'Confirmation will append replacement decision evidence and preserve history.'
      ));
    end if;

    v_preview_lines := v_preview_lines || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_strip_nulls(pg_catalog.jsonb_build_object(
        'confirmed_need_line_id', v_line.confirmed_need_line_id,
        'current_revision_id', v_revision.confirmed_need_line_revision_id,
        'current_revision_number', v_revision.revision_number,
        'current_decision_id', v_line.current_confirmed_need_line_decision_id,
        'current_decision_number', v_decision.decision_number,
        'theoretical_quantity_before', v_revision.theoretical_quantity::text,
        'proposed_quantity_before', v_revision.confirmed_quantity::text,
        'confirmed_quantity_after', v_quantity::text,
        'decision_kind', v_kind,
        'reason_code', v_reason,
        'reason_note', v_note,
        'policy_root_id', v_policy.planning_quantity_policy_id,
        'policy_revision_id', v_policy.planning_quantity_policy_revision_id,
        'policy_revision_number', v_policy.revision_number,
        'planning_step', v_policy.planning_step::text,
        'planning_tick_count', v_tick_count::text,
        'successor_revision_required', v_kind = 'ADJUSTED_QUANTITY_CONFIRMED',
        'source_membership_count', v_membership_count,
        'source_membership_hash', v_membership_hash,
        'blockers', v_line_blockers,
        'warnings', v_line_warnings
      ))
    );
    v_blockers := v_blockers || v_line_blockers;
    v_warnings := v_warnings || v_line_warnings;
  end loop;

  if pg_catalog.jsonb_array_length(v_blockers) = 0 then
    v_preview_hash := pg_catalog.encode(
      pg_catalog.sha256(pg_catalog.convert_to(
        pg_catalog.jsonb_build_object(
          'contract_version', 'RMVP-05.v1',
          'confirmed_need_batch_id', batch_id,
          'expected_batch_version', expected_batch_version,
          'ordered_preview_lines', v_preview_lines
        )::text,
        'UTF8'
      )),
      'hex'
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'success', pg_catalog.jsonb_array_length(v_blockers) = 0,
    'error_code', case when pg_catalog.jsonb_array_length(v_blockers) = 0 then null
      else v_blockers -> 0 ->> 'code' end,
    'confirmed_need_batch_id', batch_id,
    'expected_batch_version', expected_batch_version,
    'actual_batch_version', v_batch.version,
    'ordered_preview_lines', v_preview_lines,
    'blockers', v_blockers,
    'warnings', v_warnings,
    'preview_hash', v_preview_hash,
    'write_certainty', 'NO_WRITE'
  );
end;
$$;

create function atlas_core.rmvp_05_record_change(
  request jsonb,
  actor_id uuid,
  receipt_id uuid,
  batch_id uuid,
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
    'ConfirmedNeedQuantitiesConfirmed', 'PLANNING', 'ConfirmedNeedBatch', batch_id,
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
    'ConfirmedNeedQuantitiesConfirmed', 'PLANNING', 'ConfirmedNeedBatch', batch_id,
    version_before, version_after, receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id, request ->> 'reason_code', null,
    before_summary, after_summary, 'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_id;

  return pg_catalog.jsonb_build_object(
    'domain_event_id', v_event_id,
    'audit_event_id', v_audit_id
  );
end;
$$;

create function atlas_api.get_confirmed_need_review(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_confirmed_need_review';
  v_error jsonb;
  v_context jsonb;
  v_payload jsonb := request -> 'payload';
  v_workbench jsonb;
begin
  v_error := atlas_core.rmvp_05_validate_read(request, v_name);
  if v_error is not null then return v_error; end if;

  v_context := atlas_core.rmvp_05_authorize_global(
    request, 'confirmed_need_review.read', v_name, true
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;

  v_workbench := atlas_core.rmvp_05_workbench_payload(
    atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id'),
    coalesce(v_payload -> 'filters', '{}'::jsonb),
    coalesce(atlas_core.pa_05b_safe_bigint(v_payload ->> 'line_offset')::integer, 0),
    coalesce(atlas_core.pa_05b_safe_bigint(v_payload ->> 'line_limit')::integer, 100)
  );
  if v_workbench is null then
    return atlas_core.rmvp_05_error(
      request, v_name, 'CONFIRMED_NEED_BATCH_NOT_FOUND',
      'The requested Confirmed Need batch was not found.', true
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-05.v1',
    'correlation_id', request ->> 'correlation_id',
    'workbench', v_workbench
  );
exception when others then
  return atlas_core.rmvp_05_error(
    request, v_name, 'INTERNAL_READ_FAILURE',
    'The Confirmed Need review could not be returned safely.', true
  );
end;
$$;

create function atlas_api.preview_confirmed_need_confirmation(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'preview_confirmed_need_confirmation';
  v_error jsonb;
  v_context jsonb;
  v_payload jsonb := request -> 'payload';
  v_preview jsonb;
begin
  v_error := atlas_core.rmvp_05_validate_preview(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_05_authorize_global(
    request, 'confirmed_need_quantities.preview', v_name, true
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;

  v_preview := atlas_core.rmvp_05_canonical_preview(
    atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id'),
    atlas_core.pa_05b_safe_bigint(v_payload ->> 'expected_batch_version'),
    v_payload -> 'lines'
  );
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-05.v1',
    'correlation_id', request ->> 'correlation_id',
    'safe_message', case when coalesce((v_preview ->> 'success')::boolean, false)
      then 'The exact confirmation preview is ready.'
      else 'Resolve the preview blockers, then preview again.' end,
    'preview', v_preview
  );
exception when others then
  return atlas_core.rmvp_05_error(
    request, v_name, 'INTERNAL_READ_FAILURE',
    'The confirmation preview could not be returned safely.', true
  );
end;
$$;

create function atlas_api.confirm_need_quantities(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'confirm_need_quantities';
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_payload jsonb := request -> 'payload';
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id');
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_preview jsonb;
  v_preview_line jsonb;
  v_line atlas_planning.confirmed_need_lines%rowtype;
  v_revision atlas_planning.confirmed_need_line_revisions%rowtype;
  v_new_revision_id uuid;
  v_new_decision_id uuid;
  v_next_version bigint;
  v_events jsonb;
  v_response jsonb;
  v_created_revision_ids jsonb := '[]'::jsonb;
  v_superseded_revision_ids jsonb := '[]'::jsonb;
  v_created_decision_ids jsonb := '[]'::jsonb;
  v_advanced_line_ids jsonb := '[]'::jsonb;
  v_unchanged_count integer := 0;
  v_adjusted_count integer := 0;
  v_before_summary jsonb;
  v_after_summary jsonb;
begin
  v_error := atlas_core.rmvp_05_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;

  v_context := atlas_core.rmvp_05_authorize_global(
    request, 'confirmed_need_quantities.confirm', v_name, false
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_name,
    'PLANNING',
    'ConfirmedNeedBatch:' || v_batch_id::text
  );
  if v_begin ->> 'status' <> 'NEW' then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  select * into v_batch
  from atlas_planning.confirmed_need_batches b
  where b.confirmed_need_batch_id = v_batch_id
    and b.source_kind = 'NEED_GENERATION'
  for update;
  if not found then
    v_error := atlas_core.rmvp_05_error(
      request, v_name, 'CONFIRMED_NEED_BATCH_NOT_FOUND',
      'The requested Confirmed Need batch was not found.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  perform l.confirmed_need_line_id
  from atlas_planning.confirmed_need_lines l
  join pg_catalog.jsonb_array_elements(v_payload -> 'lines') item
    on l.confirmed_need_line_id = atlas_core.pa_05b_safe_uuid(item ->> 'confirmed_need_line_id')
  where l.confirmed_need_batch_id = v_batch_id
  order by l.confirmed_need_line_id
  for update of l;

  v_preview := atlas_core.rmvp_05_canonical_preview(
    v_batch_id,
    atlas_core.pa_05b_safe_bigint(request ->> 'expected_version'),
    v_payload -> 'lines'
  );
  if not coalesce((v_preview ->> 'success')::boolean, false) then
    v_error := atlas_core.rmvp_05_error(
      request,
      v_name,
      coalesce(v_preview ->> 'error_code', 'VALIDATION_FAILED'),
      'The authoritative confirmation preview is blocked. Refresh and preview again.',
      false,
      false,
      '[]'::jsonb,
      coalesce(v_preview -> 'blockers', '[]'::jsonb),
      v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_preview ->> 'preview_hash' is distinct from v_payload ->> 'preview_hash' then
    v_error := atlas_core.rmvp_05_error(
      request, v_name, 'PREVIEW_MISMATCH',
      'The authoritative inputs changed. Refresh and preview the exact Draft again.',
      false, false, '[]'::jsonb, '[]'::jsonb, v_batch.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  v_next_version := v_batch.version + 1;
  v_before_summary := pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', v_batch_id,
    'batch_version', v_batch.version,
    'selected_line_count', pg_catalog.jsonb_array_length(v_preview -> 'ordered_preview_lines')
  );

  for v_preview_line in
    select value
    from pg_catalog.jsonb_array_elements(v_preview -> 'ordered_preview_lines')
    order by value ->> 'confirmed_need_line_id'
  loop
    select * into strict v_line
    from atlas_planning.confirmed_need_lines l
    where l.confirmed_need_line_id = atlas_core.pa_05b_safe_uuid(
      v_preview_line ->> 'confirmed_need_line_id'
    );
    select * into strict v_revision
    from atlas_planning.confirmed_need_line_revisions r
    where r.confirmed_need_line_revision_id = atlas_core.pa_05b_safe_uuid(
      v_preview_line ->> 'current_revision_id'
    ) and r.is_current;

    if (v_preview_line ->> 'successor_revision_required')::boolean then
      update atlas_planning.confirmed_need_line_revisions
      set revision_status = 'SUPERSEDED', is_current = false
      where confirmed_need_line_revision_id = v_revision.confirmed_need_line_revision_id;
      v_superseded_revision_ids := v_superseded_revision_ids
        || pg_catalog.jsonb_build_array(v_revision.confirmed_need_line_revision_id);

      v_new_revision_id := gen_random_uuid();
      insert into atlas_planning.confirmed_need_line_revisions (
        confirmed_need_line_revision_id,
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
      ) values (
        v_new_revision_id,
        v_revision.confirmed_need_line_id,
        v_revision.revision_number + 1,
        null,
        v_revision.ingredient_id,
        v_revision.theoretical_quantity,
        (v_preview_line ->> 'confirmed_quantity_after')::numeric(20, 6),
        v_revision.unit_id,
        'DRAFT',
        true,
        v_revision.confirmed_need_line_revision_id,
        atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
        v_actor_id,
        v_revision.source_kind,
        v_revision.confirmed_need_batch_id,
        v_revision.need_generation_run_id,
        v_revision.need_generation_run_version,
        v_revision.need_generation_release_snapshot_id,
        v_revision.service_date,
        v_revision.customer_id,
        v_revision.school_id,
        v_revision.delivery_location_id
      );

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
        c.confirmed_need_batch_id,
        c.confirmed_need_line_id,
        v_new_revision_id,
        c.need_generation_run_id,
        c.need_generation_run_version,
        c.need_generation_release_snapshot_id,
        c.need_generation_release_snapshot_line_id,
        c.theoretical_need_line_id,
        c.service_date,
        c.customer_id,
        c.school_id,
        c.delivery_location_id,
        c.ingredient_id,
        c.source_unit_id,
        c.controlled_unit_id,
        c.source_theoretical_quantity,
        c.controlled_contribution_quantity
      from atlas_planning.confirmed_need_line_revision_contributions c
      where c.confirmed_need_line_revision_id = v_revision.confirmed_need_line_revision_id
      order by c.theoretical_need_line_id;

      v_created_revision_ids := v_created_revision_ids
        || pg_catalog.jsonb_build_array(v_new_revision_id);
      v_adjusted_count := v_adjusted_count + 1;
    else
      v_new_revision_id := v_revision.confirmed_need_line_revision_id;
      v_unchanged_count := v_unchanged_count + 1;
    end if;

    v_new_decision_id := gen_random_uuid();
    insert into atlas_planning.confirmed_need_line_decisions (
      confirmed_need_line_decision_id,
      confirmed_need_batch_id,
      confirmed_need_line_id,
      confirmed_need_line_revision_id,
      source_kind,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      unit_id,
      decision_number,
      predecessor_decision_id,
      decision_kind,
      planning_quantity_policy_id,
      planning_quantity_policy_revision_id,
      theoretical_quantity_before,
      proposed_quantity_before,
      confirmed_quantity_after,
      planning_tick_count,
      reason_code,
      reason_note,
      decided_by_actor_id,
      decided_at,
      command_id,
      confirmed_need_batch_version
    ) values (
      v_new_decision_id,
      v_batch_id,
      v_line.confirmed_need_line_id,
      v_new_revision_id,
      v_line.source_kind,
      v_line.service_date,
      v_line.customer_id,
      v_line.school_id,
      v_line.delivery_location_id,
      v_line.ingredient_id,
      v_line.controlled_unit_id,
      coalesce((v_preview_line ->> 'current_decision_number')::bigint, 0) + 1,
      atlas_core.pa_05b_safe_uuid(v_preview_line ->> 'current_decision_id'),
      v_preview_line ->> 'decision_kind',
      atlas_core.pa_05b_safe_uuid(v_preview_line ->> 'policy_root_id'),
      atlas_core.pa_05b_safe_uuid(v_preview_line ->> 'policy_revision_id'),
      (v_preview_line ->> 'theoretical_quantity_before')::numeric(20, 6),
      (v_preview_line ->> 'proposed_quantity_before')::numeric(20, 6),
      (v_preview_line ->> 'confirmed_quantity_after')::numeric(20, 6),
      (v_preview_line ->> 'planning_tick_count')::numeric(20, 0),
      v_preview_line ->> 'reason_code',
      v_preview_line ->> 'reason_note',
      v_actor_id,
      pg_catalog.transaction_timestamp(),
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      v_next_version
    );

    update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id = v_new_decision_id
    where confirmed_need_line_id = v_line.confirmed_need_line_id;

    v_created_decision_ids := v_created_decision_ids
      || pg_catalog.jsonb_build_array(v_new_decision_id);
    v_advanced_line_ids := v_advanced_line_ids
      || pg_catalog.jsonb_build_array(v_line.confirmed_need_line_id);
  end loop;

  update atlas_planning.confirmed_need_batches
  set version = v_next_version,
      updated_at = pg_catalog.transaction_timestamp()
  where confirmed_need_batch_id = v_batch_id;

  v_after_summary := pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', v_batch_id,
    'batch_version', v_next_version,
    'unchanged_accepted_line_count', v_unchanged_count,
    'adjusted_line_count', v_adjusted_count,
    'advanced_stable_line_ids', v_advanced_line_ids
  );
  v_events := atlas_core.rmvp_05_record_change(
    request, v_actor_id, v_receipt_id, v_batch_id,
    v_batch.version, v_next_version, v_before_summary, v_after_summary
  );

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-05.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'confirmed_need_batch_id', v_batch_id,
    'new_batch_version', v_next_version,
    'created_successor_revision_ids', v_created_revision_ids,
    'superseded_revision_ids', v_superseded_revision_ids,
    'created_decision_ids', v_created_decision_ids,
    'advanced_stable_line_ids', v_advanced_line_ids,
    'unchanged_accepted_line_count', v_unchanged_count,
    'adjusted_line_count', v_adjusted_count,
    'receipt_id', v_receipt_id,
    'event_id', v_events -> 'domain_event_id',
    'audit_id', v_events -> 'audit_event_id',
    'safe_operator_message', 'Confirmed Need quantities were recorded with immutable decision evidence.',
    'authoritative_readback', atlas_core.rmvp_05_workbench_payload(
      v_batch_id, '{}'::jsonb, 0, 100
    )
  );

  v_response := atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
  set constraints all immediate;
  set constraints all deferred;
  return v_response;
exception when others then
  return atlas_core.rmvp_05_error(
    request,
    v_name,
    'INTERNAL_COMMAND_FAILURE',
    'The confirmation was not committed. Refresh before trying again.',
    false,
    false
  );
end;
$$;

reset role;

grant usage on schema atlas_core, atlas_admin, atlas_planning, atlas_audit,
  atlas_api to atlas_confirmed_need_review_runtime;

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
  atlas_planning.need_generation_runs,
  atlas_planning.need_generation_release_snapshots,
  atlas_planning.need_generation_release_snapshot_lines,
  atlas_planning.theoretical_need_lines,
  atlas_planning.confirmed_need_batches,
  atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_line_revision_contributions,
  atlas_planning.confirmed_need_line_decisions,
  atlas_planning.planning_quantity_policies,
  atlas_planning.planning_quantity_policy_revisions
to atlas_confirmed_need_review_runtime;

grant insert, update on atlas_core.command_receipts
to atlas_confirmed_need_review_runtime;
grant insert on
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_line_revision_contributions,
  atlas_planning.confirmed_need_line_decisions,
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_confirmed_need_review_runtime;
grant update (version, updated_at) on atlas_planning.confirmed_need_batches
to atlas_confirmed_need_review_runtime;
grant update (current_confirmed_need_line_decision_id)
on atlas_planning.confirmed_need_lines
to atlas_confirmed_need_review_runtime;
grant update (revision_status, is_current)
on atlas_planning.confirmed_need_line_revisions
to atlas_confirmed_need_review_runtime;
-- The existing deferred H1B1 guard takes a policy-root row lock with
-- SELECT FOR UPDATE. A single-column grant authorizes that lock without
-- granting the runtime authority to change policy business attributes.
grant update (planning_quantity_policy_id)
on atlas_planning.planning_quantity_policies
to atlas_confirmed_need_review_runtime;
grant select (domain_event_id) on atlas_audit.domain_events
to atlas_confirmed_need_review_runtime;
grant select (audit_event_id) on atlas_audit.audit_events
to atlas_confirmed_need_review_runtime;

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
    'atlas_planning.need_generation_runs',
    'atlas_planning.need_generation_release_snapshots',
    'atlas_planning.need_generation_release_snapshot_lines',
    'atlas_planning.theoretical_need_lines',
    'atlas_planning.confirmed_need_batches',
    'atlas_planning.confirmed_need_lines',
    'atlas_planning.confirmed_need_line_revisions',
    'atlas_planning.confirmed_need_line_revision_contributions',
    'atlas_planning.confirmed_need_line_decisions',
    'atlas_planning.planning_quantity_policies',
    'atlas_planning.planning_quantity_policy_revisions'
  ];
begin
  foreach relation_name in array relations loop
    execute pg_catalog.format(
      'create policy rmvp_05_confirmed_need_select on %s for select to atlas_confirmed_need_review_runtime using (true)',
      relation_name
    );
  end loop;
end
$$;

create policy rmvp_05_receipt_insert
on atlas_core.command_receipts for insert to atlas_confirmed_need_review_runtime
with check (true);
create policy rmvp_05_receipt_update
on atlas_core.command_receipts for update to atlas_confirmed_need_review_runtime
using (true) with check (true);
create policy rmvp_05_batch_update
on atlas_planning.confirmed_need_batches for update to atlas_confirmed_need_review_runtime
using (source_kind = 'NEED_GENERATION') with check (source_kind = 'NEED_GENERATION');
create policy rmvp_05_line_update
on atlas_planning.confirmed_need_lines for update to atlas_confirmed_need_review_runtime
using (source_kind = 'NEED_GENERATION') with check (source_kind = 'NEED_GENERATION');
create policy rmvp_05_revision_insert
on atlas_planning.confirmed_need_line_revisions for insert to atlas_confirmed_need_review_runtime
with check (source_kind = 'NEED_GENERATION');
create policy rmvp_05_revision_update
on atlas_planning.confirmed_need_line_revisions for update to atlas_confirmed_need_review_runtime
using (source_kind = 'NEED_GENERATION') with check (source_kind = 'NEED_GENERATION');
create policy rmvp_05_policy_root_lock
on atlas_planning.planning_quantity_policies for update to atlas_confirmed_need_review_runtime
using (true) with check (true);
create policy rmvp_05_contribution_insert
on atlas_planning.confirmed_need_line_revision_contributions for insert to atlas_confirmed_need_review_runtime
with check (true);
create policy rmvp_05_decision_insert
on atlas_planning.confirmed_need_line_decisions for insert to atlas_confirmed_need_review_runtime
with check (source_kind = 'NEED_GENERATION');
create policy rmvp_05_domain_event_insert
on atlas_audit.domain_events for insert to atlas_confirmed_need_review_runtime
with check (source_domain = 'PLANNING' and aggregate_type = 'ConfirmedNeedBatch');
create policy rmvp_05_audit_event_insert
on atlas_audit.audit_events for insert to atlas_confirmed_need_review_runtime
with check (source_domain = 'PLANNING' and aggregate_type = 'ConfirmedNeedBatch');
create policy rmvp_05_domain_event_select
on atlas_audit.domain_events for select to atlas_confirmed_need_review_runtime
using (source_domain = 'PLANNING' and aggregate_type = 'ConfirmedNeedBatch');
create policy rmvp_05_audit_event_select
on atlas_audit.audit_events for select to atlas_confirmed_need_review_runtime
using (source_domain = 'PLANNING' and aggregate_type = 'ConfirmedNeedBatch');

revoke execute on function
  atlas_core.rmvp_05_error(jsonb, text, text, text, boolean, boolean, jsonb, jsonb, bigint),
  atlas_core.rmvp_05_authorize_global(jsonb, text, text, boolean),
  atlas_core.rmvp_05_validate_read(jsonb, text),
  atlas_core.rmvp_05_validate_preview(jsonb, text),
  atlas_core.rmvp_05_validate_command(jsonb, text),
  atlas_core.rmvp_05_workbench_payload(uuid, jsonb, integer, integer),
  atlas_core.rmvp_05_canonical_preview(uuid, bigint, jsonb),
  atlas_core.rmvp_05_record_change(jsonb, uuid, uuid, uuid, bigint, bigint, jsonb, jsonb)
from public, anon, authenticated, service_role;

-- RMVP-04 transferred this exact date parser to its dedicated runtime and
-- revoked the migration runner's membership afterward. Assume that owner only
-- long enough to grant the single helper dependency, then remove membership.
grant atlas_need_generation_runtime to postgres with set true;
set role atlas_need_generation_runtime;
grant execute on function atlas_core.rmvp_04_safe_date(text)
to atlas_confirmed_need_review_runtime;
reset role;
revoke atlas_need_generation_runtime from postgres;

grant execute on function
  atlas_core.rmvp_05_error(jsonb, text, text, text, boolean, boolean, jsonb, jsonb, bigint),
  atlas_core.rmvp_05_authorize_global(jsonb, text, text, boolean),
  atlas_core.rmvp_05_validate_read(jsonb, text),
  atlas_core.rmvp_05_validate_preview(jsonb, text),
  atlas_core.rmvp_05_validate_command(jsonb, text),
  atlas_core.rmvp_05_workbench_payload(uuid, jsonb, integer, integer),
  atlas_core.rmvp_05_canonical_preview(uuid, bigint, jsonb),
  atlas_core.rmvp_05_record_change(jsonb, uuid, uuid, uuid, bigint, bigint, jsonb, jsonb),
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(jsonb, uuid, text, text, text, uuid, uuid, uuid),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean)
to atlas_confirmed_need_review_runtime;

grant atlas_confirmed_need_review_runtime to postgres with set true;
grant create on schema atlas_core, atlas_api to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_05_error(jsonb, text, text, text, boolean, boolean, jsonb, jsonb, bigint)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_05_authorize_global(jsonb, text, text, boolean)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_05_validate_read(jsonb, text)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_05_validate_preview(jsonb, text)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_05_validate_command(jsonb, text)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_05_workbench_payload(uuid, jsonb, integer, integer)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_05_canonical_preview(uuid, bigint, jsonb)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_core.rmvp_05_record_change(jsonb, uuid, uuid, uuid, bigint, bigint, jsonb, jsonb)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_api.get_confirmed_need_review(jsonb)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_api.preview_confirmed_need_confirmation(jsonb)
  owner to atlas_confirmed_need_review_runtime;
alter function atlas_api.confirm_need_quantities(jsonb)
  owner to atlas_confirmed_need_review_runtime;
revoke create on schema atlas_core, atlas_api from atlas_confirmed_need_review_runtime;

revoke execute on function
  atlas_api.get_confirmed_need_review(jsonb),
  atlas_api.preview_confirmed_need_confirmation(jsonb),
  atlas_api.confirm_need_quantities(jsonb)
from public, anon, authenticated, service_role;

grant usage on schema atlas_api to authenticated;
grant execute on function
  atlas_api.get_confirmed_need_review(jsonb),
  atlas_api.preview_confirmed_need_confirmation(jsonb),
  atlas_api.confirm_need_quantities(jsonb)
to authenticated;

comment on function atlas_api.get_confirmed_need_review(jsonb) is
  'RMVP-05 authorized shaped Confirmed Need batch, exact proposal, policy, blocker, action, and immutable decision-history read.';
comment on function atlas_api.preview_confirmed_need_confirmation(jsonb) is
  'RMVP-05 deterministic write-free exact-numeric quantity decision preview with sole-policy and whole-tick evidence.';
comment on function atlas_api.confirm_need_quantities(jsonb) is
  'RMVP-05 idempotent preview-bound mixed unchanged/adjusted quantity confirmation with append-only H1B1 evidence.';

revoke atlas_confirmed_need_review_runtime from postgres;
