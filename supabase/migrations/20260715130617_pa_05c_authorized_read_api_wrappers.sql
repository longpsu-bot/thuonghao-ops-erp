-- PA-05C: bounded, authorized, shaped read wrappers for supplier-direct Slice 1.
-- Read responses are advisory only and are never command safety gates.

create or replace function atlas_core.pa_05c_read_error(
  request jsonb,
  read_name text,
  error_code text,
  safe_message text,
  field_errors jsonb default '[]'::jsonb
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'PA-05C.v1',
    'error_code', error_code,
    'safe_message', safe_message,
    'domain', 'REPORTING',
    'read_name', read_name,
    'field_errors', coalesce(field_errors, '[]'::jsonb),
    'correlation_id', request ->> 'correlation_id'
  );
$$;

create or replace function atlas_core.pa_05c_validate_envelope(
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
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05c_read_error(
      coalesce(request, '{}'::jsonb), read_name, 'VALIDATION_FAILED',
      'The read request must be a JSON object.',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'request', 'message', 'A JSON object is required.')
      )
    );
  end if;

  if request ->> 'contract_version' is distinct from 'PA-05C.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use PA-05C.v1.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'requested_by_auth_subject', 'message', 'A valid UUID is required.')
    );
  end if;
  if request ? 'correlation_id'
     and nullif(request ->> 'correlation_id', '') is not null
     and atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'correlation_id', 'message', 'When supplied, correlation_id must be a UUID.')
    );
  end if;
  if request -> 'payload' is null or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'A JSON object is required.')
    );
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05c_read_error(
      request, read_name, 'VALIDATION_FAILED', 'The read envelope is invalid.', v_errors
    );
  end if;
  return null;
end;
$$;

-- Evaluates the complete actor/capability/scope tuple for one candidate read row.
-- Read selectors must be authorized as a set before JSON shaping and are also
-- filtered by this helper at the row boundary as defence in depth.
create or replace function atlas_core.pa_05c_actor_can_read_scope(
  actor_id uuid,
  capability_code text,
  customer_id uuid,
  delivery_location_id uuid,
  dispatch_trip_id uuid
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_core.actor_role_memberships arm
    join atlas_core.roles r on r.role_id = arm.role_id
    join atlas_core.role_capabilities rc on rc.role_id = r.role_id
    join atlas_core.capabilities c on c.capability_id = rc.capability_id
    where arm.actor_id = pa_05c_actor_can_read_scope.actor_id
      and arm.membership_status = 'ACTIVE'
      and arm.effective_from <= pg_catalog.transaction_timestamp()
      and (arm.effective_to is null or arm.effective_to > pg_catalog.transaction_timestamp())
      and r.role_status = 'ACTIVE'
      and c.capability_status = 'ACTIVE'
      and c.capability_code = pa_05c_actor_can_read_scope.capability_code
  ) and exists (
    select 1
    from atlas_core.actor_scopes s
    where s.actor_id = pa_05c_actor_can_read_scope.actor_id
      and s.scope_status = 'ACTIVE'
      and s.effective_from <= pg_catalog.transaction_timestamp()
      and (s.effective_to is null or s.effective_to > pg_catalog.transaction_timestamp())
      and (
        s.scope_kind = 'GLOBAL'
        or (s.scope_kind = 'CUSTOMER' and s.customer_id = pa_05c_actor_can_read_scope.customer_id)
        or (s.scope_kind = 'DELIVERY_LOCATION'
          and s.delivery_location_id = pa_05c_actor_can_read_scope.delivery_location_id)
        or (s.scope_kind = 'DISPATCH_TRIP'
          and s.dispatch_trip_id = pa_05c_actor_can_read_scope.dispatch_trip_id)
      )
  );
$$;

create or replace function atlas_core.pa_05c_aggregate_scope(
  aggregate_type text,
  aggregate_id uuid
)
returns table (
  customer_id uuid,
  delivery_location_id uuid,
  dispatch_trip_id uuid,
  public_reference text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select s.customer_id, s.delivery_location_id, s.dispatch_trip_id, s.public_reference
  from (
    select dr.customer_id, dr.delivery_location_id, null::uuid as dispatch_trip_id,
      null::text as public_reference
    from atlas_evidence.supplier_receiving_evidence sre
    join atlas_procurement.purchase_order_line_revisions polr
      on polr.purchase_order_line_revision_id = sre.purchase_order_line_revision_id
    join atlas_procurement.fulfilment_allocation_line_revisions falr
      on falr.fulfilment_allocation_line_revision_id = polr.fulfilment_allocation_line_revision_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = (
        select drl.dispatch_requirement_id
        from atlas_planning.dispatch_requirement_lines drl
        where drl.dispatch_requirement_line_id = drlr.dispatch_requirement_line_id
      )
    where pa_05c_aggregate_scope.aggregate_type = 'SUPPLIER_RECEIVING_EVIDENCE'
      and sre.supplier_receiving_evidence_id = pa_05c_aggregate_scope.aggregate_id

    union all
    select dr.customer_id, dr.delivery_location_id, null::uuid, null::text
    from atlas_evidence.evidence_applications ea
    join atlas_procurement.fulfilment_allocation_line_revisions falr
      on falr.fulfilment_allocation_line_revision_id = ea.fulfilment_allocation_line_revision_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
    join atlas_planning.dispatch_requirement_lines drl
      on drl.dispatch_requirement_line_id = drlr.dispatch_requirement_line_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drl.dispatch_requirement_id
    where pa_05c_aggregate_scope.aggregate_type = 'EVIDENCE_APPLICATION'
      and ea.evidence_application_id = pa_05c_aggregate_scope.aggregate_id

    union all
    select ds.customer_id, ds.delivery_location_id, dt.dispatch_trip_id, dt.trip_reference
    from atlas_dispatch.dispatch_trips dt
    left join atlas_dispatch.dispatch_stops ds on ds.dispatch_trip_id = dt.dispatch_trip_id
    where pa_05c_aggregate_scope.aggregate_type = 'DISPATCH_TRIP'
      and dt.dispatch_trip_id = pa_05c_aggregate_scope.aggregate_id
    union all
    select ds.customer_id, ds.delivery_location_id, ds.dispatch_trip_id, dt.trip_reference
    from atlas_dispatch.dispatch_stops ds
    join atlas_dispatch.dispatch_trips dt on dt.dispatch_trip_id = ds.dispatch_trip_id
    where pa_05c_aggregate_scope.aggregate_type = 'DISPATCH_STOP'
      and ds.dispatch_stop_id = pa_05c_aggregate_scope.aggregate_id

    union all
    select dr.customer_id, dr.delivery_location_id, dl.dispatch_trip_id, dt.trip_reference
    from atlas_dispatch.dispatch_loads dl
    join atlas_dispatch.dispatch_trips dt on dt.dispatch_trip_id = dl.dispatch_trip_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirements dr on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    where pa_05c_aggregate_scope.aggregate_type = 'DISPATCH_LOAD'
      and dl.dispatch_load_id = pa_05c_aggregate_scope.aggregate_id

    union all
    select ds.customer_id, ds.delivery_location_id, ds.dispatch_trip_id, dt.trip_reference
    from atlas_dispatch.delivery_confirmations dc
    join atlas_dispatch.dispatch_stops ds on ds.dispatch_stop_id = dc.dispatch_stop_id
    join atlas_dispatch.dispatch_trips dt on dt.dispatch_trip_id = ds.dispatch_trip_id
    where pa_05c_aggregate_scope.aggregate_type = 'DELIVERY_CONFIRMATION'
      and dc.delivery_confirmation_id = pa_05c_aggregate_scope.aggregate_id

    union all
    select dr.customer_id, dr.delivery_location_id, null::uuid, null::text
    from atlas_planning.dispatch_requirements dr
    where pa_05c_aggregate_scope.aggregate_type = 'DISPATCH_REQUIREMENT'
      and dr.dispatch_requirement_id = pa_05c_aggregate_scope.aggregate_id
  ) s;
$$;

create or replace function atlas_api.get_dispatch_evidence_readiness(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_dispatch_evidence_readiness';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_trip_id uuid;
  v_requirement_revision_id uuid;
  v_source_revision_id uuid;
  v_selector_count integer;
  v_scope_count integer;
  v_unauthorized_scope_count integer;
  v_scope_customer_id uuid;
  v_scope_location_id uuid;
  v_scope_trip_id uuid;
  v_items jsonb;
begin
  v_error := atlas_core.pa_05c_validate_envelope(request, v_name);
  if v_error is not null then return v_error; end if;

  v_trip_id := atlas_core.pa_05b_safe_uuid(request -> 'payload' ->> 'dispatch_trip_id');
  v_requirement_revision_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'dispatch_requirement_revision_id'
  );
  v_source_revision_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'wholesale_order_line_revision_id'
  );
  v_selector_count := (v_trip_id is not null)::integer
    + (v_requirement_revision_id is not null)::integer
    + (v_source_revision_id is not null)::integer;
  if v_selector_count <> 1 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'UNBOUNDED_OR_AMBIGUOUS_SELECTOR',
      'Provide exactly one supported bounded readiness selector.'
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'REPORTING', v_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  with selector_scopes as (
    select distinct dr.customer_id, dr.delivery_location_id, dt.dispatch_trip_id
    from atlas_planning.dispatch_requirements dr
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_id = dr.dispatch_requirement_id
    left join atlas_dispatch.dispatch_stops ds
      on ds.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    left join atlas_dispatch.dispatch_trips dt on dt.dispatch_trip_id = ds.dispatch_trip_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    join atlas_planning.purchase_handoff_line_revisions phlr
      on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_line_revisions cnlr
      on cnlr.confirmed_need_line_revision_id = phlr.confirmed_need_line_revision_id
    where (v_trip_id is not null and dt.dispatch_trip_id = v_trip_id)
       or (v_requirement_revision_id is not null and drr.dispatch_requirement_revision_id = v_requirement_revision_id)
       or (v_source_revision_id is not null and cnlr.wholesale_order_line_revision_id = v_source_revision_id)
  )
  select count(*)::integer,
    count(*) filter (where not atlas_core.pa_05c_actor_can_read_scope(
      v_actor_id, 'dispatch_evidence_readiness.read', customer_id, delivery_location_id, dispatch_trip_id
    ))::integer,
    (pg_catalog.array_agg(customer_id order by customer_id))[1],
    (pg_catalog.array_agg(delivery_location_id order by delivery_location_id))[1],
    (pg_catalog.array_agg(dispatch_trip_id order by dispatch_trip_id))[1]
  into v_scope_count, v_unauthorized_scope_count,
    v_scope_customer_id, v_scope_location_id, v_scope_trip_id
  from selector_scopes;

  if v_scope_count = 0 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'NOT_FOUND', 'No supplier-direct readiness context matches the selector.'
    );
  end if;
  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'dispatch_evidence_readiness.read', 'REPORTING', v_name,
    v_scope_customer_id, v_scope_location_id, v_scope_trip_id
  );
  if v_error is not null and v_error ->> 'error_code' = 'CAPABILITY_DENIED' then return v_error; end if;
  if v_unauthorized_scope_count > 0 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'SCOPE_DENIED', 'The selected readiness context includes an unauthorized Atlas scope.'
    );
  end if;

  with lines as (
    select
      dr.customer_id, dr.delivery_location_id, dr.dispatch_requirement_id,
      drr.dispatch_requirement_revision_id, drlr.dispatch_requirement_line_revision_id,
      falr.fulfilment_allocation_line_revision_id, falr.allocated_quantity,
      falr.unit_id, dt.dispatch_trip_id, dt.trip_reference, dt.trip_status,
      ds.dispatch_stop_id, ds.stop_sequence, ds.stop_status,
      coalesce(l.loaded_quantity, 0) as loaded_quantity,
      coalesce(e.valid_applied_quantity, 0) as valid_applied_quantity,
      coalesce(e.has_invalid_evidence, false) as has_invalid_evidence,
      coalesce(e.has_evidence, false) as has_evidence,
      coalesce(l.delivered, false) as delivered,
      coalesce(e.evidence_references, '[]'::jsonb) as evidence_references
    from atlas_planning.dispatch_requirements dr
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_id = dr.dispatch_requirement_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    join atlas_planning.purchase_handoff_line_revisions phlr
      on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_line_revisions cnlr
      on cnlr.confirmed_need_line_revision_id = phlr.confirmed_need_line_revision_id
    join atlas_procurement.fulfilment_allocation_line_revisions falr
      on falr.dispatch_requirement_line_revision_id = drlr.dispatch_requirement_line_revision_id
    left join atlas_dispatch.dispatch_stops ds
      on ds.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    left join atlas_dispatch.dispatch_trips dt on dt.dispatch_trip_id = ds.dispatch_trip_id
    left join lateral (
      select
        coalesce(sum(dll.loaded_quantity) filter (
          where dll.line_status = 'CONFIRMED' and dl.load_status = 'CONFIRMED'
        ), 0) as loaded_quantity,
        exists (
          select 1
          from atlas_dispatch.dispatch_load_lines delivered_line
          join atlas_dispatch.delivery_confirmation_lines dcl
            on dcl.dispatch_load_line_id = delivered_line.dispatch_load_line_id
          join atlas_dispatch.delivery_confirmations dc
            on dc.delivery_confirmation_id = dcl.delivery_confirmation_id
          where delivered_line.dispatch_stop_id = ds.dispatch_stop_id
            and delivered_line.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
            and dc.confirmation_status = 'VALID'
            and dc.delivery_outcome = 'DELIVERED'
        ) as delivered
      from atlas_dispatch.dispatch_load_lines dll
      join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
      where dll.dispatch_stop_id = ds.dispatch_stop_id
        and dll.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
    ) l on true
    left join lateral (
      select
        coalesce(sum(ea.applied_quantity) filter (
          where ea.application_status = 'VALID' and sre.evidence_status = 'VALID'
        ), 0) as valid_applied_quantity,
        coalesce(bool_or(sre.evidence_status in ('VOIDED', 'SUPERSEDED')
          or ea.application_status in ('VOIDED', 'SUPERSEDED')), false) as has_invalid_evidence,
        coalesce(bool_or(ea.evidence_application_id is not null), false) as has_evidence,
        coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'supplier_receiving_evidence_id', sre.supplier_receiving_evidence_id,
          'evidence_reference', sre.evidence_reference,
          'evidence_status', sre.evidence_status,
          'evidence_application_id', ea.evidence_application_id,
          'application_status', ea.application_status
        ) order by ea.recorded_at, ea.evidence_application_id)
          filter (where sre.supplier_receiving_evidence_id is not null), '[]'::jsonb) as evidence_references
      from atlas_evidence.evidence_applications ea
      join atlas_evidence.supplier_receiving_evidence sre
        on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
      where ea.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
    ) e on true
    where (
      (v_trip_id is not null and dt.dispatch_trip_id = v_trip_id)
      or (v_requirement_revision_id is not null and drr.dispatch_requirement_revision_id = v_requirement_revision_id)
      or (v_source_revision_id is not null and cnlr.wholesale_order_line_revision_id = v_source_revision_id)
    ) and atlas_core.pa_05c_actor_can_read_scope(
        v_actor_id, 'dispatch_evidence_readiness.read', dr.customer_id, dr.delivery_location_id, dt.dispatch_trip_id
      )
  ), shaped as (
    select *, case
      when delivered then 'DELIVERED'
      when loaded_quantity = 0 then 'NOT_LOADED'
      when not has_evidence then 'MISSING_EVIDENCE'
      when valid_applied_quantity = 0 and has_invalid_evidence then 'VOIDED_OR_SUPERSEDED_EVIDENCE'
      when valid_applied_quantity < loaded_quantity then 'PARTIAL_EVIDENCE'
      else 'READY'
    end as readiness_status
    from lines
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'trip_reference', trip_reference,
    'dispatch_trip_id', dispatch_trip_id,
    'trip_status', trip_status,
    'dispatch_stop_id', dispatch_stop_id,
    'stop_sequence', stop_sequence,
    'stop_status', stop_status,
    'dispatch_requirement_id', dispatch_requirement_id,
    'dispatch_requirement_revision_id', dispatch_requirement_revision_id,
    'dispatch_requirement_line_revision_id', dispatch_requirement_line_revision_id,
    'fulfilment_allocation_line_revision_id', fulfilment_allocation_line_revision_id,
    'unit_id', unit_id,
    'allocated_quantity', allocated_quantity,
    'loaded_quantity', loaded_quantity,
    'applied_evidence_quantity', valid_applied_quantity,
    'evidence_references', evidence_references,
    'evidence_status', case when has_invalid_evidence then 'HAS_VOIDED_OR_SUPERSEDED' when has_evidence then 'VALID' else 'MISSING' end,
    'evidence_application_status', case when valid_applied_quantity > 0 then 'VALID' when has_evidence then 'INVALID' else 'MISSING' end,
    'readiness_status', readiness_status,
    'blockers', case readiness_status
      when 'NOT_LOADED' then pg_catalog.jsonb_build_array('No confirmed load is available.')
      when 'MISSING_EVIDENCE' then pg_catalog.jsonb_build_array('No supplier evidence is applied.')
      when 'PARTIAL_EVIDENCE' then pg_catalog.jsonb_build_array('Applied evidence is below the loaded quantity.')
      when 'VOIDED_OR_SUPERSEDED_EVIDENCE' then pg_catalog.jsonb_build_array('Only voided or superseded evidence is available.')
      else '[]'::jsonb end,
    'warnings', case when has_invalid_evidence and valid_applied_quantity > 0
      then pg_catalog.jsonb_build_array('Historical voided or superseded evidence is present.')
      else '[]'::jsonb end
  ) order by dispatch_trip_id, stop_sequence, fulfilment_allocation_line_revision_id), '[]'::jsonb)
  into v_items from shaped;

  return pg_catalog.jsonb_build_object(
    'success', true, 'contract_version', 'PA-05C.v1',
    'selector', request -> 'payload',
    'authorized_scope', pg_catalog.jsonb_build_object(
      'customer_id', v_scope_customer_id, 'delivery_location_id', v_scope_location_id,
      'dispatch_trip_id', coalesce(v_trip_id, v_scope_trip_id)
    ),
    'readiness_items', v_items,
    'advisory_only', true,
    'safe_operator_message', 'Authorized dispatch evidence readiness returned.'
  );
exception when others then
  return atlas_core.pa_05c_read_error(
    request, v_name, 'INTERNAL_READ_FAILURE', 'Dispatch evidence readiness could not be returned safely.'
  );
end;
$$;

create or replace function atlas_api.get_operator_blockers(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_operator_blockers';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_trip_id uuid;
  v_customer_id uuid;
  v_location_id uuid;
  v_service_date date;
  v_mode_count integer;
  v_scope_count integer;
  v_unauthorized_scope_count integer;
  v_scope_customer_id uuid;
  v_scope_location_id uuid;
  v_blockers jsonb;
begin
  v_error := atlas_core.pa_05c_validate_envelope(request, v_name);
  if v_error is not null then return v_error; end if;

  v_trip_id := atlas_core.pa_05b_safe_uuid(request -> 'payload' ->> 'dispatch_trip_id');
  v_customer_id := atlas_core.pa_05b_safe_uuid(request -> 'payload' ->> 'customer_id');
  v_location_id := atlas_core.pa_05b_safe_uuid(request -> 'payload' ->> 'delivery_location_id');
  begin v_service_date := (request -> 'payload' ->> 'service_date')::date;
  exception when invalid_datetime_format or datetime_field_overflow then v_service_date := null; end;
  v_mode_count := (v_trip_id is not null)::integer
    + (v_service_date is not null and v_customer_id is not null and v_location_id is null)::integer
    + (v_service_date is not null and v_location_id is not null and v_customer_id is null)::integer;
  if v_mode_count <> 1 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'UNBOUNDED_OR_AMBIGUOUS_SELECTOR',
      'Provide exactly one supported bounded blocker selector.'
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'REPORTING', v_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  with selector_scopes as (
    select distinct dr.customer_id, dr.delivery_location_id, ds.dispatch_trip_id
    from atlas_planning.dispatch_requirements dr
    join atlas_planning.dispatch_requirement_revisions drr on drr.dispatch_requirement_id = dr.dispatch_requirement_id
    left join atlas_dispatch.dispatch_stops ds on ds.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    where (v_trip_id is not null and ds.dispatch_trip_id = v_trip_id)
       or (v_customer_id is not null and dr.customer_id = v_customer_id and dr.service_date = v_service_date)
       or (v_location_id is not null and dr.delivery_location_id = v_location_id and dr.service_date = v_service_date)
  )
  select count(*)::integer,
    count(*) filter (where not atlas_core.pa_05c_actor_can_read_scope(
      v_actor_id, 'operator_blockers.read', customer_id, delivery_location_id, dispatch_trip_id
    ))::integer,
    (pg_catalog.array_agg(customer_id order by customer_id))[1],
    (pg_catalog.array_agg(delivery_location_id order by delivery_location_id))[1]
  into v_scope_count, v_unauthorized_scope_count, v_scope_customer_id, v_scope_location_id
  from selector_scopes;
  if v_scope_count = 0 then
    return atlas_core.pa_05c_read_error(request, v_name, 'NOT_FOUND', 'No supplier-direct operating context matches the selector.');
  end if;
  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'operator_blockers.read', 'REPORTING', v_name,
    v_scope_customer_id, v_scope_location_id, v_trip_id
  );
  if v_error is not null and v_error ->> 'error_code' = 'CAPABILITY_DENIED' then return v_error; end if;
  if v_unauthorized_scope_count > 0 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'SCOPE_DENIED', 'The selected blocker context includes an unauthorized Atlas scope.'
    );
  end if;

  with context_lines as (
    select dr.customer_id, dr.delivery_location_id, dr.service_date,
      dr.dispatch_requirement_id, drr.dispatch_requirement_revision_id,
      falr.fulfilment_allocation_line_revision_id,
      dt.dispatch_trip_id, dt.trip_reference, dt.trip_status, dt.created_at as trip_created_at,
      ds.dispatch_stop_id, ds.stop_status,
      coalesce(l.loaded_quantity, 0) loaded_quantity,
      coalesce(e.valid_evidence_quantity, 0) valid_evidence_quantity,
      coalesce(e.has_evidence, false) has_evidence,
      coalesce(e.has_invalid_evidence, false) has_invalid_evidence,
      coalesce(l.delivered, false) delivered,
      coalesce(e.observed_at, dt.created_at) observed_at
    from atlas_planning.dispatch_requirements dr
    join atlas_planning.dispatch_requirement_revisions drr on drr.dispatch_requirement_id = dr.dispatch_requirement_id
    join atlas_planning.dispatch_requirement_line_revisions drlr on drlr.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    join atlas_procurement.fulfilment_allocation_line_revisions falr on falr.dispatch_requirement_line_revision_id = drlr.dispatch_requirement_line_revision_id
    left join atlas_dispatch.dispatch_stops ds on ds.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
    left join atlas_dispatch.dispatch_trips dt on dt.dispatch_trip_id = ds.dispatch_trip_id
    left join lateral (
      select
        coalesce(sum(dll.loaded_quantity) filter (
          where dll.line_status = 'CONFIRMED' and dl.load_status = 'CONFIRMED'
        ), 0) as loaded_quantity,
        exists (
          select 1
          from atlas_dispatch.dispatch_load_lines delivered_line
          join atlas_dispatch.delivery_confirmation_lines dcl
            on dcl.dispatch_load_line_id = delivered_line.dispatch_load_line_id
          join atlas_dispatch.delivery_confirmations dc
            on dc.delivery_confirmation_id = dcl.delivery_confirmation_id
          where delivered_line.dispatch_stop_id = ds.dispatch_stop_id
            and delivered_line.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
            and dc.confirmation_status = 'VALID'
            and dc.delivery_outcome = 'DELIVERED'
        ) as delivered
      from atlas_dispatch.dispatch_load_lines dll
      join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
      where dll.dispatch_stop_id = ds.dispatch_stop_id
        and dll.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
    ) l on true
    left join lateral (
      select
        coalesce(sum(ea.applied_quantity) filter (
          where ea.application_status = 'VALID' and sre.evidence_status = 'VALID'
        ), 0) as valid_evidence_quantity,
        coalesce(bool_or(ea.evidence_application_id is not null), false) as has_evidence,
        coalesce(bool_or(sre.evidence_status in ('VOIDED','SUPERSEDED')
          or ea.application_status in ('VOIDED','SUPERSEDED')), false) as has_invalid_evidence,
        min(sre.recorded_at) as observed_at
      from atlas_evidence.evidence_applications ea
      join atlas_evidence.supplier_receiving_evidence sre
        on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
      where ea.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
    ) e on true
    where (
      (v_trip_id is not null and dt.dispatch_trip_id = v_trip_id)
      or (v_customer_id is not null and dr.customer_id = v_customer_id and dr.service_date = v_service_date)
      or (v_location_id is not null and dr.delivery_location_id = v_location_id and dr.service_date = v_service_date)
    ) and atlas_core.pa_05c_actor_can_read_scope(
      v_actor_id, 'operator_blockers.read', dr.customer_id, dr.delivery_location_id, dt.dispatch_trip_id
    )
  ), blocker_rows as (
    select c.*, b.blocker_type, b.severity, b.source_domain, b.safe_message, b.suggested_owning_team
    from context_lines c
    cross join lateral (
      select * from (values
        ('NO_SUPPLIER_EVIDENCE', 'ERROR', 'EVIDENCE', 'No supplier evidence is applied.', 'EVIDENCE', not c.has_evidence),
        ('EVIDENCE_PARTIAL', 'ERROR', 'EVIDENCE', 'Applied evidence is below the confirmed load.', 'EVIDENCE', c.loaded_quantity > 0 and c.valid_evidence_quantity > 0 and c.valid_evidence_quantity < c.loaded_quantity),
        ('EVIDENCE_VOIDED', 'ERROR', 'EVIDENCE', 'Supplier evidence is voided or superseded.', 'EVIDENCE', c.has_invalid_evidence and c.valid_evidence_quantity = 0),
        ('NOT_LOADED', 'ERROR', 'DISPATCH', 'No confirmed load is available.', 'DISPATCH', c.loaded_quantity = 0 and not c.delivered),
        ('DEPARTURE_BLOCKED', 'ERROR', 'DISPATCH', 'Departure is blocked by missing load or valid evidence.', 'DISPATCH', c.trip_status in ('PLANNED','ASSIGNED','LOADED') and (c.loaded_quantity = 0 or c.valid_evidence_quantity < c.loaded_quantity)),
        ('DELIVERY_PENDING', 'INFO', 'DISPATCH', 'Delivery confirmation is pending.', 'DISPATCH', c.trip_status in ('IN_TRANSIT','PARTIALLY_DELIVERED') and not c.delivered),
        ('DELIVERY_COMPLETED', 'INFO', 'DISPATCH', 'Delivery is complete.', 'DISPATCH', c.delivered)
      ) as x(blocker_type, severity, source_domain, safe_message, suggested_owning_team, applies)
      where x.applies
    ) b
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'blocker_type', blocker_type, 'severity', severity, 'source_domain', source_domain,
    'safe_message', safe_message,
    'affected_opaque_ids', pg_catalog.jsonb_build_object(
      'dispatch_trip_id', dispatch_trip_id, 'dispatch_stop_id', dispatch_stop_id,
      'dispatch_requirement_revision_id', dispatch_requirement_revision_id,
      'fulfilment_allocation_line_revision_id', fulfilment_allocation_line_revision_id
    ),
    'public_references', pg_catalog.jsonb_build_object('trip_reference', trip_reference),
    'suggested_owning_team', suggested_owning_team,
    'observed_at', observed_at
  ) order by observed_at, blocker_type, fulfilment_allocation_line_revision_id), '[]'::jsonb)
  into v_blockers from blocker_rows;

  return pg_catalog.jsonb_build_object(
    'success', true, 'contract_version', 'PA-05C.v1', 'selector', request -> 'payload',
    'authorized_scope', pg_catalog.jsonb_build_object(
      'customer_id', v_scope_customer_id, 'delivery_location_id', v_scope_location_id,
      'dispatch_trip_id', v_trip_id
    ),
    'blocker_count', pg_catalog.jsonb_array_length(v_blockers),
    'blockers', v_blockers,
    'safe_operator_message', 'Authorized operator blockers returned.'
  );
exception when others then
  return atlas_core.pa_05c_read_error(
    request, v_name, 'INTERNAL_READ_FAILURE', 'Operator blockers could not be returned safely.'
  );
end;
$$;

create or replace function atlas_api.get_command_audit_timeline(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_command_audit_timeline';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_command_id uuid;
  v_correlation_id uuid;
  v_aggregate_type text;
  v_aggregate_id uuid;
  v_selector_count integer;
  v_scope_count integer;
  v_unresolved_scope_count integer;
  v_scope_customer_id uuid;
  v_scope_location_id uuid;
  v_scope_trip_id uuid;
  v_scope_public_reference text;
  v_receipt jsonb;
  v_domain_events jsonb;
  v_audit_events jsonb;
begin
  v_error := atlas_core.pa_05c_validate_envelope(request, v_name);
  if v_error is not null then return v_error; end if;
  v_command_id := atlas_core.pa_05b_safe_uuid(request -> 'payload' ->> 'command_id');
  v_correlation_id := atlas_core.pa_05b_safe_uuid(request -> 'payload' ->> 'correlation_id');
  v_aggregate_type := nullif(pg_catalog.btrim(request -> 'payload' ->> 'aggregate_type'), '');
  v_aggregate_id := atlas_core.pa_05b_safe_uuid(request -> 'payload' ->> 'aggregate_id');
  v_selector_count := (v_command_id is not null)::integer + (v_correlation_id is not null)::integer
    + (v_aggregate_type is not null and v_aggregate_id is not null)::integer;
  if v_selector_count <> 1
     or ((v_aggregate_type is null) <> (v_aggregate_id is null)) then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'UNBOUNDED_OR_AMBIGUOUS_SELECTOR',
      'Provide exactly one command, correlation, or complete aggregate selector.'
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'REPORTING', v_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  with targets as (
    select distinct e.aggregate_type, e.aggregate_id
    from (
      select de.aggregate_type, de.aggregate_id, de.command_id, de.correlation_id
      from atlas_audit.domain_events de
      union all
      select ae.aggregate_type, ae.aggregate_id, ae.command_id, ae.correlation_id
      from atlas_audit.audit_events ae
    ) e
    where (v_command_id is not null and e.command_id = v_command_id)
       or (v_correlation_id is not null and e.correlation_id = v_correlation_id)
       or (v_aggregate_type is not null and e.aggregate_type = v_aggregate_type and e.aggregate_id = v_aggregate_id)
  ), target_scope_counts as (
    select count(*) filter (where not exists (
      select 1
      from atlas_core.pa_05c_aggregate_scope(t.aggregate_type, t.aggregate_id) s
    ))::integer as unresolved_scope_count
    from targets t
  ), scopes as (
    select s.customer_id, s.delivery_location_id, s.dispatch_trip_id, s.public_reference
    from targets t
    cross join lateral atlas_core.pa_05c_aggregate_scope(t.aggregate_type, t.aggregate_id) s
  ), scope_groups as (
    select customer_id, delivery_location_id, dispatch_trip_id,
      max(public_reference) as public_reference
    from scopes
    group by customer_id, delivery_location_id, dispatch_trip_id
  )
  select count(*)::integer,
    max(tsc.unresolved_scope_count),
    (pg_catalog.array_agg(customer_id order by customer_id))[1],
    (pg_catalog.array_agg(delivery_location_id order by delivery_location_id))[1],
    (pg_catalog.array_agg(dispatch_trip_id order by dispatch_trip_id))[1],
    min(public_reference)
  into v_scope_count, v_unresolved_scope_count, v_scope_customer_id, v_scope_location_id,
    v_scope_trip_id, v_scope_public_reference
  from scope_groups
  cross join target_scope_counts tsc;

  if v_scope_count = 0 or v_unresolved_scope_count > 0 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'NOT_FOUND_OR_UNSUPPORTED',
      'No authorized supplier-direct timeline context matches the selector.'
    );
  end if;
  if v_scope_count > 1 then
    return atlas_core.pa_05c_read_error(
      request, v_name, 'AMBIGUOUS_SCOPE',
      'The selected timeline spans more than one relational scope.'
    );
  end if;
  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'command_audit_timeline.read', 'REPORTING', v_name,
    v_scope_customer_id, v_scope_location_id, v_scope_trip_id
  );
  if v_error is not null then return v_error; end if;

  select pg_catalog.to_jsonb(r) into v_receipt
  from (
    select cr.command_id, cr.correlation_id, cr.command_name, cr.outcome,
      cr.error_code, cr.actor_id, a.display_name as actor_display_reference,
      cr.started_at, cr.completed_at
    from atlas_core.command_receipts cr
    join atlas_core.actors a on a.actor_id = cr.actor_id
    where (v_command_id is not null and cr.command_id = v_command_id)
       or (v_correlation_id is not null and cr.correlation_id = v_correlation_id)
    order by cr.started_at, cr.command_receipt_id
    limit 1
  ) r;

  with selected as (
    select * from (
      select 'DOMAIN'::text event_kind, de.domain_event_id stable_id,
        de.occurred_at, de.recorded_at, de.event_type, de.source_domain,
        de.aggregate_type, de.aggregate_id, de.aggregate_version,
        de.command_id, de.correlation_id, de.actor_id,
        null::text reason_code, null::text reason_note
       from atlas_audit.domain_events de
       where (
         (v_command_id is not null and de.command_id = v_command_id)
         or (v_correlation_id is not null and de.correlation_id = v_correlation_id)
         or (v_aggregate_type is not null and de.aggregate_type = v_aggregate_type and de.aggregate_id = v_aggregate_id)
       ) and exists (
           select 1 from atlas_core.pa_05c_aggregate_scope(de.aggregate_type, de.aggregate_id) scope
           where atlas_core.pa_05c_actor_can_read_scope(
             v_actor_id, 'command_audit_timeline.read',
             scope.customer_id, scope.delivery_location_id, scope.dispatch_trip_id
           )
         )
      union all
      select 'AUDIT', ae.audit_event_id, ae.occurred_at, ae.recorded_at,
        ae.event_type, ae.source_domain, ae.aggregate_type, ae.aggregate_id,
        ae.aggregate_version_after, ae.command_id, ae.correlation_id, ae.actor_id,
        ae.reason_code, ae.reason_note
       from atlas_audit.audit_events ae
       where (
         (v_command_id is not null and ae.command_id = v_command_id)
         or (v_correlation_id is not null and ae.correlation_id = v_correlation_id)
         or (v_aggregate_type is not null and ae.aggregate_type = v_aggregate_type and ae.aggregate_id = v_aggregate_id)
       ) and exists (
           select 1 from atlas_core.pa_05c_aggregate_scope(ae.aggregate_type, ae.aggregate_id) scope
           where atlas_core.pa_05c_actor_can_read_scope(
             v_actor_id, 'command_audit_timeline.read',
             scope.customer_id, scope.delivery_location_id, scope.dispatch_trip_id
           )
         )
    ) all_events
    order by occurred_at, stable_id
    limit 100
  )
  select
    coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'domain_event_id', s.stable_id, 'event_type', s.event_type,
      'source_domain', s.source_domain, 'aggregate_type', s.aggregate_type,
      'aggregate_id', s.aggregate_id, 'aggregate_version', s.aggregate_version,
      'command_id', s.command_id, 'correlation_id', s.correlation_id,
      'actor_id', s.actor_id, 'actor_display_reference', a.display_name,
      'occurred_at', s.occurred_at, 'recorded_at', s.recorded_at
    ) order by s.occurred_at, s.stable_id) filter (where s.event_kind = 'DOMAIN'), '[]'::jsonb),
    coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'audit_event_id', s.stable_id, 'event_type', s.event_type,
      'source_domain', s.source_domain, 'aggregate_type', s.aggregate_type,
      'aggregate_id', s.aggregate_id, 'aggregate_version', s.aggregate_version,
      'command_id', s.command_id, 'correlation_id', s.correlation_id,
      'actor_id', s.actor_id, 'actor_display_reference', a.display_name,
      'reason_code', s.reason_code, 'reason_note', s.reason_note,
      'occurred_at', s.occurred_at, 'recorded_at', s.recorded_at
    ) order by s.occurred_at, s.stable_id) filter (where s.event_kind = 'AUDIT'), '[]'::jsonb)
  into v_domain_events, v_audit_events
  from selected s
  join atlas_core.actors a on a.actor_id = s.actor_id;

  return pg_catalog.jsonb_build_object(
    'success', true, 'contract_version', 'PA-05C.v1', 'selector', request -> 'payload',
    'authorized_scope', pg_catalog.jsonb_build_object(
      'customer_id', v_scope_customer_id, 'delivery_location_id', v_scope_location_id,
      'dispatch_trip_id', v_scope_trip_id
    ),
    'public_aggregate_reference', v_scope_public_reference,
    'command_receipt_summary', v_receipt,
    'domain_events', v_domain_events,
    'audit_events', v_audit_events,
    'event_limit', 100,
    'safe_operator_message', 'Authorized command audit timeline returned.'
  );
exception when others then
  return atlas_core.pa_05c_read_error(
    request, v_name, 'INTERNAL_READ_FAILURE', 'The command audit timeline could not be returned safely.'
  );
end;
$$;

-- Minimum read-only runtime privileges and select-only RLS policies.
grant usage on schema atlas_audit to atlas_read_runtime;
grant select on
  atlas_core.command_receipts,
  atlas_admin.customers,
  atlas_admin.delivery_locations,
  atlas_planning.dispatch_requirement_revisions,
  atlas_procurement.fulfilment_allocation_revisions,
  atlas_dispatch.dispatch_plans,
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_read_runtime;

create policy pa_05c_read_select on atlas_core.command_receipts
  for select to atlas_read_runtime using (true);
create policy pa_05c_read_select on atlas_admin.customers
  for select to atlas_read_runtime using (true);
create policy pa_05c_read_select on atlas_admin.delivery_locations
  for select to atlas_read_runtime using (true);
create policy pa_05c_read_select on atlas_planning.dispatch_requirement_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05c_read_select on atlas_procurement.fulfilment_allocation_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05c_read_select on atlas_dispatch.dispatch_plans
  for select to atlas_read_runtime using (true);
create policy pa_05c_read_select on atlas_audit.domain_events
  for select to atlas_read_runtime using (true);
create policy pa_05c_read_select on atlas_audit.audit_events
  for select to atlas_read_runtime using (true);

alter function atlas_core.pa_05c_read_error(jsonb, text, text, text, jsonb) owner to atlas_owner;
alter function atlas_core.pa_05c_validate_envelope(jsonb, text) owner to atlas_owner;
alter function atlas_core.pa_05c_actor_can_read_scope(uuid, text, uuid, uuid, uuid) owner to atlas_owner;
alter function atlas_core.pa_05c_aggregate_scope(text, uuid) owner to atlas_owner;

grant atlas_read_runtime to postgres with set true;
grant create on schema atlas_api to atlas_read_runtime;
alter function atlas_api.get_dispatch_evidence_readiness(jsonb) owner to atlas_read_runtime;
alter function atlas_api.get_operator_blockers(jsonb) owner to atlas_read_runtime;
alter function atlas_api.get_command_audit_timeline(jsonb) owner to atlas_read_runtime;
revoke create on schema atlas_api from atlas_read_runtime;

revoke execute on function atlas_core.pa_05c_read_error(jsonb, text, text, text, jsonb),
  atlas_core.pa_05c_validate_envelope(jsonb, text),
  atlas_core.pa_05c_actor_can_read_scope(uuid, text, uuid, uuid, uuid),
  atlas_core.pa_05c_aggregate_scope(text, uuid)
from public, anon, authenticated, service_role;
grant execute on function atlas_core.pa_05c_read_error(jsonb, text, text, text, jsonb),
  atlas_core.pa_05c_validate_envelope(jsonb, text),
  atlas_core.pa_05c_actor_can_read_scope(uuid, text, uuid, uuid, uuid),
  atlas_core.pa_05c_aggregate_scope(text, uuid)
to atlas_read_runtime;

revoke execute on function atlas_api.get_dispatch_evidence_readiness(jsonb),
  atlas_api.get_operator_blockers(jsonb),
  atlas_api.get_command_audit_timeline(jsonb)
from public, anon, service_role;
grant execute on function atlas_api.get_dispatch_evidence_readiness(jsonb),
  atlas_api.get_operator_blockers(jsonb),
  atlas_api.get_command_audit_timeline(jsonb)
to authenticated;

comment on function atlas_api.get_dispatch_evidence_readiness(jsonb)
  is 'PA-05C bounded authorized evidence-readiness read; advisory only and never a command gate.';
comment on function atlas_api.get_operator_blockers(jsonb)
  is 'PA-05C bounded authorized operator blocker read; creates no task or workflow state.';
comment on function atlas_api.get_command_audit_timeline(jsonb)
  is 'PA-05C bounded authorized audit timeline with allowlisted fields and a 100-event limit.';
comment on schema atlas_api
  is 'Function-only Atlas Data API boundary; PA-05B commands/trace plus PA-05C authorized read wrappers.';

revoke atlas_read_runtime from postgres;
