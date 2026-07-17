-- PA-05B-H3: bounded successful Dispatch Trip closure.
--
-- This migration adds exactly one public command and one private,
-- command-specific reconciliation helper. It reuses the existing Dispatch
-- runtime and PA-04 through PA-05F schema objects. No authoritative table,
-- column, view, trigger, sequence, role, queue, job, or seed row is added.

create or replace function atlas_core.pa_05b_h3_trip_closure_signature(
  p_dispatch_trip_id uuid,
  p_completed_at timestamptz
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with trip_root as materialized (
    select dt.dispatch_trip_id, dt.dispatch_plan_id, dp.plan_status,
           dt.trip_status, dt.driver_actor_id, dt.vehicle_reference,
           dt.departed_at, dt.completed_at, dt.version,
           driver.actor_type as driver_actor_type,
           driver.actor_status as driver_actor_status
    from atlas_dispatch.dispatch_trips dt
    join atlas_dispatch.dispatch_plans dp
      on dp.dispatch_plan_id = dt.dispatch_plan_id
    left join atlas_core.actors driver
      on driver.actor_id = dt.driver_actor_id
    where dt.dispatch_trip_id = p_dispatch_trip_id
  ),
  raw_stops as materialized (
    select ds.dispatch_stop_id, ds.dispatch_trip_id, ds.stop_sequence,
           ds.dispatch_requirement_revision_id, ds.customer_id,
           ds.delivery_location_id, ds.stop_status, ds.version
    from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = p_dispatch_trip_id
  ),
  memberships as materialized (
    select rs.dispatch_stop_id, rs.stop_sequence, rs.stop_status,
           dpr.dispatch_plan_requirement_id,
           drr.dispatch_requirement_revision_id,
           dr.dispatch_requirement_id, dr.customer_id,
           dr.delivery_location_id,
           far.fulfilment_allocation_revision_id,
           fa.fulfilment_allocation_id
    from trip_root tr
    join raw_stops rs on true
    join atlas_dispatch.dispatch_plan_requirements dpr
      on dpr.dispatch_plan_id = tr.dispatch_plan_id
     and dpr.dispatch_requirement_revision_id = rs.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    join atlas_procurement.fulfilment_allocation_revisions far
      on far.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
    join atlas_procurement.fulfilment_allocations fa
      on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
     and fa.dispatch_requirement_id = dr.dispatch_requirement_id
    join atlas_admin.delivery_locations loc
      on loc.delivery_location_id = dr.delivery_location_id
     and loc.customer_id = dr.customer_id
    where rs.stop_status = 'DELIVERED'
      and rs.customer_id = dr.customer_id
      and rs.delivery_location_id = dr.delivery_location_id
      and dr.source_of_need = 'WHOLESALE'
      and dr.requirement_status = 'RELEASED'
      and drr.revision_status = 'RELEASED'
      and drr.is_current
      and fa.allocation_status = 'READY_FOR_DISPATCH'
      and far.revision_status = 'READY_FOR_DISPATCH'
      and far.is_current
  ),
  planning_lines as materialized (
    select distinct m.dispatch_stop_id, m.dispatch_requirement_id,
           m.dispatch_requirement_revision_id,
           drlr.dispatch_requirement_line_revision_id,
           drlr.dispatch_requirement_line_id, drlr.ingredient_id,
           drlr.required_quantity, drlr.unit_id
    from memberships m
    join atlas_planning.dispatch_requirement_lines drl
      on drl.dispatch_requirement_id = m.dispatch_requirement_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.dispatch_requirement_line_id = drl.dispatch_requirement_line_id
     and drlr.dispatch_requirement_revision_id = m.dispatch_requirement_revision_id
  ),
  allocation_lines as materialized (
    select distinct m.dispatch_stop_id, m.fulfilment_allocation_id,
           m.fulfilment_allocation_revision_id,
           falr.fulfilment_allocation_line_revision_id,
           falr.fulfilment_allocation_line_id,
           fal.dispatch_requirement_line_id,
           falr.dispatch_requirement_line_revision_id,
           falr.fulfilment_source_type, falr.supplier_id,
           falr.allocated_quantity, falr.unit_id, falr.line_status,
           fal.portion_sequence
    from memberships m
    join atlas_procurement.fulfilment_allocation_lines fal
      on fal.fulfilment_allocation_id = m.fulfilment_allocation_id
    join atlas_procurement.fulfilment_allocation_line_revisions falr
      on falr.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
     and falr.fulfilment_allocation_revision_id = m.fulfilment_allocation_revision_id
  ),
  valid_source_lines as materialized (
    select pl.dispatch_stop_id, pl.dispatch_requirement_line_revision_id,
           al.fulfilment_allocation_line_revision_id, pl.ingredient_id,
           pl.required_quantity, pl.unit_id
    from planning_lines pl
    join allocation_lines al
      on al.dispatch_stop_id = pl.dispatch_stop_id
     and al.dispatch_requirement_line_id = pl.dispatch_requirement_line_id
     and al.dispatch_requirement_line_revision_id = pl.dispatch_requirement_line_revision_id
     and al.fulfilment_source_type = 'SUPPLIER_PO'
     and al.portion_sequence = 1
     and al.line_status = 'READY_FOR_EVIDENCE'
     and al.allocated_quantity = pl.required_quantity
     and al.unit_id = pl.unit_id
  ),
  raw_loads as materialized (
    select dl.dispatch_load_id, dl.dispatch_trip_id,
           dl.dispatch_requirement_revision_id,
           dl.fulfilment_allocation_revision_id,
           dl.load_status, dl.loaded_at, dl.version
    from atlas_dispatch.dispatch_loads dl
    where dl.dispatch_trip_id = p_dispatch_trip_id
  ),
  valid_loads as materialized (
    select distinct rl.dispatch_load_id, m.dispatch_stop_id,
           m.dispatch_plan_requirement_id,
           m.dispatch_requirement_revision_id,
           m.fulfilment_allocation_revision_id
    from raw_loads rl
    join memberships m
      on m.dispatch_requirement_revision_id = rl.dispatch_requirement_revision_id
     and m.fulfilment_allocation_revision_id = rl.fulfilment_allocation_revision_id
    where rl.load_status = 'CONFIRMED'
      and rl.loaded_at is not null
  ),
  raw_load_lines as materialized (
    select distinct dll.dispatch_load_line_id, dll.dispatch_load_id,
           dll.dispatch_stop_id,
           dll.dispatch_requirement_line_revision_id,
           dll.fulfilment_allocation_line_revision_id,
           dll.ingredient_id, dll.loaded_quantity, dll.unit_id,
           dll.line_status
    from atlas_dispatch.dispatch_load_lines dll
    join atlas_dispatch.dispatch_loads dl
      on dl.dispatch_load_id = dll.dispatch_load_id
    join atlas_dispatch.dispatch_stops ds
      on ds.dispatch_stop_id = dll.dispatch_stop_id
    where dl.dispatch_trip_id = p_dispatch_trip_id
       or ds.dispatch_trip_id = p_dispatch_trip_id
  ),
  valid_load_lines as materialized (
    select distinct rll.dispatch_load_line_id, rll.dispatch_load_id,
           rll.dispatch_stop_id, rll.ingredient_id,
           rll.loaded_quantity, rll.unit_id
    from raw_load_lines rll
    join valid_loads vl
      on vl.dispatch_load_id = rll.dispatch_load_id
     and vl.dispatch_stop_id = rll.dispatch_stop_id
    join valid_source_lines vsl
      on vsl.dispatch_stop_id = rll.dispatch_stop_id
     and vsl.dispatch_requirement_line_revision_id = rll.dispatch_requirement_line_revision_id
     and vsl.fulfilment_allocation_line_revision_id = rll.fulfilment_allocation_line_revision_id
     and vsl.ingredient_id = rll.ingredient_id
     and vsl.unit_id = rll.unit_id
     and vsl.required_quantity = rll.loaded_quantity
    where rll.line_status = 'CONFIRMED'
  ),
  raw_confirmations as materialized (
    select dc.delivery_confirmation_id, dc.dispatch_stop_id,
           dc.revision_number, dc.delivery_outcome,
           dc.confirmation_status,
           dc.supersedes_delivery_confirmation_id,
           dc.confirmed_at
    from atlas_dispatch.delivery_confirmations dc
    join atlas_dispatch.dispatch_stops ds
      on ds.dispatch_stop_id = dc.dispatch_stop_id
    where ds.dispatch_trip_id = p_dispatch_trip_id
  ),
  valid_confirmations as materialized (
    select distinct rc.delivery_confirmation_id, rc.dispatch_stop_id,
           rc.confirmed_at
    from raw_confirmations rc
    join memberships m on m.dispatch_stop_id = rc.dispatch_stop_id
    join valid_loads vl on vl.dispatch_stop_id = m.dispatch_stop_id
    join trip_root tr on true
    where rc.revision_number = 1
      and rc.delivery_outcome = 'DELIVERED'
      and rc.confirmation_status = 'VALID'
      and rc.supersedes_delivery_confirmation_id is null
      and rc.confirmed_at >= tr.departed_at
      and rc.confirmed_at <= p_completed_at
      and rc.confirmed_at <= pg_catalog.transaction_timestamp()
  ),
  raw_confirmation_lines as materialized (
    select distinct dcl.delivery_confirmation_line_id,
           dcl.delivery_confirmation_id,
           dcl.dispatch_load_line_id,
           dcl.delivered_quantity, dcl.returned_quantity,
           dcl.exception_quantity, dcl.unit_id
    from atlas_dispatch.delivery_confirmation_lines dcl
    join atlas_dispatch.delivery_confirmations dc
      on dc.delivery_confirmation_id = dcl.delivery_confirmation_id
    join atlas_dispatch.dispatch_stops confirmation_stop
      on confirmation_stop.dispatch_stop_id = dc.dispatch_stop_id
    join atlas_dispatch.dispatch_load_lines dll
      on dll.dispatch_load_line_id = dcl.dispatch_load_line_id
    join atlas_dispatch.dispatch_loads dl
      on dl.dispatch_load_id = dll.dispatch_load_id
    where confirmation_stop.dispatch_trip_id = p_dispatch_trip_id
       or dl.dispatch_trip_id = p_dispatch_trip_id
  ),
  valid_confirmation_lines as materialized (
    select distinct rcl.delivery_confirmation_line_id,
           rcl.delivery_confirmation_id,
           rcl.dispatch_load_line_id
    from raw_confirmation_lines rcl
    join valid_confirmations vc
      on vc.delivery_confirmation_id = rcl.delivery_confirmation_id
    join valid_load_lines vll
      on vll.dispatch_load_line_id = rcl.dispatch_load_line_id
     and vll.dispatch_stop_id = vc.dispatch_stop_id
    where rcl.delivered_quantity = vll.loaded_quantity
      and rcl.returned_quantity = 0
      and rcl.exception_quantity = 0
      and rcl.unit_id = vll.unit_id
  ),
  confirmation_successors as materialized (
    select successor.delivery_confirmation_id
    from atlas_dispatch.delivery_confirmations successor
    where successor.supersedes_delivery_confirmation_id in (
      select rc.delivery_confirmation_id from raw_confirmations rc
    )
  )
  select pg_catalog.jsonb_build_object(
    'trip_count', (select count(*) from trip_root),
    'raw_stop_count', (select count(*) from raw_stops),
    'membership_row_count', (select count(*) from memberships),
    'valid_stop_count', (select count(distinct dispatch_stop_id) from memberships),
    'distinct_membership_count', (
      select count(distinct dispatch_plan_requirement_id) from memberships
    ),
    'planning_line_count', (
      select count(distinct dispatch_requirement_line_revision_id) from planning_lines
    ),
    'allocation_line_count', (
      select count(distinct fulfilment_allocation_line_revision_id) from allocation_lines
    ),
    'valid_source_line_count', (select count(*) from valid_source_lines),
    'raw_load_count', (select count(*) from raw_loads),
    'valid_load_count', (select count(distinct dispatch_load_id) from valid_loads),
    'raw_load_line_count', (select count(*) from raw_load_lines),
    'valid_load_line_count', (select count(*) from valid_load_lines),
    'raw_confirmation_count', (select count(*) from raw_confirmations),
    'valid_confirmation_count', (
      select count(distinct delivery_confirmation_id) from valid_confirmations
    ),
    'raw_confirmation_line_count', (select count(*) from raw_confirmation_lines),
    'valid_confirmation_line_count', (select count(*) from valid_confirmation_lines),
    'confirmation_successor_count', (select count(*) from confirmation_successors),
    'max_confirmation_at', (select max(confirmed_at) from raw_confirmations),
    'trip', (
      select pg_catalog.jsonb_build_object(
        'dispatch_trip_id', tr.dispatch_trip_id,
        'dispatch_plan_id', tr.dispatch_plan_id,
        'plan_status', tr.plan_status,
        'trip_status', tr.trip_status,
        'driver_actor_id', tr.driver_actor_id,
        'driver_actor_type', tr.driver_actor_type,
        'driver_actor_status', tr.driver_actor_status,
        'vehicle_reference', tr.vehicle_reference,
        'departed_at', tr.departed_at,
        'completed_at', tr.completed_at,
        'version', tr.version
      ) from trip_root tr
    ),
    'raw_stops', (
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'dispatch_stop_id', rs.dispatch_stop_id,
          'stop_sequence', rs.stop_sequence,
          'dispatch_requirement_revision_id', rs.dispatch_requirement_revision_id,
          'customer_id', rs.customer_id,
          'delivery_location_id', rs.delivery_location_id,
          'stop_status', rs.stop_status,
          'version', rs.version
        ) order by rs.dispatch_stop_id
      ), '[]'::jsonb) from raw_stops rs
    ),
    'memberships', (
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'dispatch_stop_id', m.dispatch_stop_id,
          'dispatch_plan_requirement_id', m.dispatch_plan_requirement_id,
          'dispatch_requirement_revision_id', m.dispatch_requirement_revision_id,
          'dispatch_requirement_id', m.dispatch_requirement_id,
          'fulfilment_allocation_revision_id', m.fulfilment_allocation_revision_id,
          'fulfilment_allocation_id', m.fulfilment_allocation_id,
          'customer_id', m.customer_id,
          'delivery_location_id', m.delivery_location_id
        ) order by m.dispatch_stop_id, m.dispatch_plan_requirement_id
      ), '[]'::jsonb) from memberships m
    ),
    'planning_lines', (
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'dispatch_stop_id', pl.dispatch_stop_id,
          'dispatch_requirement_line_revision_id', pl.dispatch_requirement_line_revision_id,
          'ingredient_id', pl.ingredient_id,
          'required_quantity', pl.required_quantity,
          'unit_id', pl.unit_id
        ) order by pl.dispatch_stop_id, pl.dispatch_requirement_line_revision_id
      ), '[]'::jsonb) from planning_lines pl
    ),
    'allocation_lines', (
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'dispatch_stop_id', al.dispatch_stop_id,
          'fulfilment_allocation_line_revision_id', al.fulfilment_allocation_line_revision_id,
          'dispatch_requirement_line_revision_id', al.dispatch_requirement_line_revision_id,
          'fulfilment_source_type', al.fulfilment_source_type,
          'allocated_quantity', al.allocated_quantity,
          'unit_id', al.unit_id,
          'line_status', al.line_status
        ) order by al.dispatch_stop_id, al.fulfilment_allocation_line_revision_id
      ), '[]'::jsonb) from allocation_lines al
    ),
    'raw_loads', (
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.to_jsonb(rl) order by rl.dispatch_load_id
      ), '[]'::jsonb) from raw_loads rl
    ),
    'raw_load_lines', (
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.to_jsonb(rll) order by rll.dispatch_load_line_id
      ), '[]'::jsonb) from raw_load_lines rll
    ),
    'raw_confirmations', (
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.to_jsonb(rc) order by rc.delivery_confirmation_id
      ), '[]'::jsonb) from raw_confirmations rc
    ),
    'raw_confirmation_lines', (
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.to_jsonb(rcl) order by rcl.delivery_confirmation_line_id
      ), '[]'::jsonb) from raw_confirmation_lines rcl
    )
  );
$$;

alter function atlas_core.pa_05b_h3_trip_closure_signature(uuid, timestamptz)
  owner to atlas_owner;
revoke execute on function
  atlas_core.pa_05b_h3_trip_closure_signature(uuid, timestamptz)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.pa_05b_h3_trip_closure_signature(uuid, timestamptz)
to atlas_dispatch_command_runtime;

-- The UPDATE grant is lock-only. Forced RLS has no UPDATE policy for this
-- relation, so the runtime can take deterministic row locks but cannot mutate
-- a confirmation line.
grant update on atlas_dispatch.delivery_confirmation_lines
to atlas_dispatch_command_runtime;

grant atlas_dispatch_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_dispatch_command_runtime;
set role atlas_dispatch_command_runtime;

create or replace function atlas_api.close_successful_trip(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'close_successful_trip';
  v_allowed_keys constant text[] := array[
    'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
    'expected_version', 'requested_by_auth_subject', 'requested_at',
    'reason_code', 'reason_note', 'payload'
  ];
  v_payload jsonb;
  v_errors jsonb := '[]'::jsonb;
  v_requested_at timestamptz;
  v_completed_at timestamptz;
  v_trip_id uuid;
  v_actor_context jsonb;
  v_locked_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_signature jsonb;
  v_locked_signature jsonb;
  v_trip_count bigint;
  v_raw_stop_count bigint;
  v_resolved_stop_count bigint;
  v_expected_version bigint;
  v_current_version bigint;
  v_new_version bigint;
  v_plan_id uuid;
  v_driver_actor_id uuid;
  v_trip_status text;
  v_departed_at timestamptz;
  v_current_completed_at timestamptz;
  v_driver_actor_type text;
  v_driver_actor_status text;
  v_vehicle_reference text;
  v_row record;
  v_error jsonb;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb), 'VALIDATION_FAILED',
      'The command request must be a JSON object.', 'DISPATCH', v_command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'request', 'message', 'A JSON object is required.')
      )
    );
  end if;

  if not (request ?& v_allowed_keys) or request - v_allowed_keys <> '{}'::jsonb then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'request', 'message', 'Use exactly the PA-05B-H3 command-envelope fields.'
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from 'PA-05B-H3.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use PA-05B-H3.v1.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'command_id', 'message', 'A valid UUID is required.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'correlation_id', 'message', 'A valid UUID is required.')
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
  v_expected_version := atlas_core.pa_05b_safe_bigint(request ->> 'expected_version');
  if v_expected_version is null or v_expected_version <= 0 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'expected_version', 'message', 'A positive integer version is required.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'requested_by_auth_subject', 'message', 'A valid UUID is required.')
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at');
  if v_requested_at is null or v_requested_at > pg_catalog.transaction_timestamp() then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'requested_at', 'message', 'A valid non-future timestamp is required.')
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = '' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'reason_code', 'message', 'A reason code is required.')
    );
  end if;
  if not (request ? 'reason_note')
     or (
       request -> 'reason_note' <> 'null'::jsonb
       and pg_catalog.jsonb_typeof(request -> 'reason_note') <> 'string'
     ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'reason_note', 'message', 'reason_note is required and must be text or null.')
    );
  end if;

  v_payload := request -> 'payload';
  if v_payload is null or pg_catalog.jsonb_typeof(v_payload) <> 'object'
     or not (v_payload ?& array['dispatch_trip_id', 'completed_at'])
     or v_payload - array['dispatch_trip_id', 'completed_at'] <> '{}'::jsonb then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'Provide only dispatch_trip_id and completed_at.'
      )
    );
  else
    v_trip_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_trip_id');
    v_completed_at := atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'completed_at');
    if v_trip_id is null then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.dispatch_trip_id', 'message', 'A valid UUID is required.')
      );
    end if;
    if v_completed_at is null or v_completed_at > pg_catalog.transaction_timestamp() then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.completed_at', 'message', 'A valid non-future timestamp is required.')
      );
    end if;
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The PA-05B-H3 command request is invalid.',
      'DISPATCH', v_command_name, false, v_errors
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'DISPATCH', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select count(*)::bigint
    into v_trip_count
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_plans dp
    on dp.dispatch_plan_id = dt.dispatch_plan_id
  where dt.dispatch_trip_id = v_trip_id;

  if v_trip_count <> 1 then
    return atlas_core.pa_05b_command_error(
      request, 'NOT_FOUND', 'The Dispatch Trip was not found.',
      'DISPATCH', v_command_name
    );
  end if;

  if not exists (
    select 1
    from atlas_core.actor_role_memberships arm
    join atlas_core.roles r on r.role_id = arm.role_id
    join atlas_core.role_capabilities rc on rc.role_id = r.role_id
    join atlas_core.capabilities c on c.capability_id = rc.capability_id
    where arm.actor_id = v_actor_id
      and arm.membership_status = 'ACTIVE'
      and arm.effective_from <= pg_catalog.transaction_timestamp()
      and (arm.effective_to is null or arm.effective_to > pg_catalog.transaction_timestamp())
      and r.role_status = 'ACTIVE'
      and c.capability_code = 'dispatch_trip.close_successful'
      and c.owning_domain = 'DISPATCH'
      and c.capability_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_command_error(
      request, 'CAPABILITY_DENIED',
      'The actor does not have the required Dispatch capability.',
      'DISPATCH', v_command_name
    );
  end if;

  select count(*)::bigint
    into v_raw_stop_count
  from atlas_dispatch.dispatch_stops ds
  where ds.dispatch_trip_id = v_trip_id;

  select count(*)::bigint
    into v_resolved_stop_count
  from atlas_dispatch.dispatch_stops ds
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = drr.dispatch_requirement_id
  join atlas_admin.delivery_locations loc
    on loc.delivery_location_id = dr.delivery_location_id
  where ds.dispatch_trip_id = v_trip_id;

  if v_resolved_stop_count <> v_raw_stop_count then
    return atlas_core.pa_05b_command_error(
      request, 'TRIP_RECONCILIATION_FAILED',
      'Every stop must resolve to an authoritative Planning destination.',
      'DISPATCH', v_command_name
    );
  end if;

  if v_raw_stop_count = 0 then
    v_authorization_error := atlas_core.pa_05b_authorize_actor(
      request, v_actor_id, 'dispatch_trip.close_successful',
      'DISPATCH', v_command_name, null, null, v_trip_id
    );
    if v_authorization_error is not null then return v_authorization_error; end if;
  else
    for v_row in
      select distinct dr.customer_id, dr.delivery_location_id
      from atlas_dispatch.dispatch_stops ds
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
      where ds.dispatch_trip_id = v_trip_id
      order by dr.customer_id, dr.delivery_location_id
    loop
      v_authorization_error := atlas_core.pa_05b_authorize_actor(
        request, v_actor_id, 'dispatch_trip.close_successful',
        'DISPATCH', v_command_name, v_row.customer_id,
        v_row.delivery_location_id, v_trip_id
      );
      if v_authorization_error is not null then return v_authorization_error; end if;
    end loop;
  end if;

  v_signature := atlas_core.pa_05b_h3_trip_closure_signature(
    v_trip_id, v_completed_at
  );

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'DISPATCH',
    'trip:' || v_trip_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  v_plan_id := atlas_core.pa_05b_safe_uuid(v_signature #>> '{trip,dispatch_plan_id}');
  v_driver_actor_id := atlas_core.pa_05b_safe_uuid(v_signature #>> '{trip,driver_actor_id}');

  -- Receipt and Core identity/authorization rows are locked first.
  perform 1 from atlas_core.actors a
    where a.actor_id in (v_actor_id, v_driver_actor_id)
    order by a.actor_id for key share;
  perform 1 from atlas_core.actor_auth_subjects aas
    where aas.actor_id = v_actor_id
    order by aas.actor_auth_subject_id for key share;
  perform 1 from atlas_core.actor_role_memberships arm
    where arm.actor_id = v_actor_id
    order by arm.actor_role_membership_id for key share;
  perform 1 from atlas_core.roles r
    where r.role_id in (
      select arm.role_id from atlas_core.actor_role_memberships arm
      where arm.actor_id = v_actor_id
    ) order by r.role_id for key share;
  perform 1 from atlas_core.role_capabilities rc
    where rc.role_id in (
      select arm.role_id from atlas_core.actor_role_memberships arm
      where arm.actor_id = v_actor_id
    ) order by rc.role_capability_id for key share;
  perform 1 from atlas_core.capabilities c
    where c.capability_id in (
      select rc.capability_id
      from atlas_core.role_capabilities rc
      join atlas_core.actor_role_memberships arm on arm.role_id = rc.role_id
      where arm.actor_id = v_actor_id
    ) order by c.capability_id for key share;
  perform 1 from atlas_core.actor_scopes s
    where s.actor_id = v_actor_id
    order by s.actor_scope_id for key share;

  -- Admin, Planning, and Procurement identities follow the shared lock order.
  perform 1 from atlas_admin.customers c
    where c.customer_id in (
      select dr.customer_id
      from atlas_dispatch.dispatch_stops ds
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
      where ds.dispatch_trip_id = v_trip_id
    ) order by c.customer_id for key share;
  perform 1 from atlas_admin.delivery_locations loc
    where loc.delivery_location_id in (
      select dr.delivery_location_id
      from atlas_dispatch.dispatch_stops ds
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
      where ds.dispatch_trip_id = v_trip_id
    ) order by loc.delivery_location_id for key share;
  perform 1 from atlas_admin.ingredients i
    where i.ingredient_id in (
      select dll.ingredient_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll
        on dll.dispatch_load_id = dl.dispatch_load_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (
      select dll.unit_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll
        on dll.dispatch_load_id = dl.dispatch_load_id
      where dl.dispatch_trip_id = v_trip_id
      union
      select dcl.unit_id
      from atlas_dispatch.delivery_confirmation_lines dcl
      join atlas_dispatch.dispatch_load_lines dll
        on dll.dispatch_load_line_id = dcl.dispatch_load_line_id
      join atlas_dispatch.dispatch_loads dl
        on dl.dispatch_load_id = dll.dispatch_load_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by u.unit_id for key share;

  perform 1 from atlas_planning.dispatch_requirements dr
    where dr.dispatch_requirement_id in (
      select drr.dispatch_requirement_id
      from atlas_dispatch.dispatch_stops ds
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
      where ds.dispatch_trip_id = v_trip_id
    ) order by dr.dispatch_requirement_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_revisions drr
    where drr.dispatch_requirement_revision_id in (
      select ds.dispatch_requirement_revision_id
      from atlas_dispatch.dispatch_stops ds
      where ds.dispatch_trip_id = v_trip_id
    ) order by drr.dispatch_requirement_revision_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_lines drl
    where drl.dispatch_requirement_id in (
      select drr.dispatch_requirement_id
      from atlas_dispatch.dispatch_stops ds
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
      where ds.dispatch_trip_id = v_trip_id
    ) order by drl.dispatch_requirement_line_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_line_revisions drlr
    where drlr.dispatch_requirement_revision_id in (
      select ds.dispatch_requirement_revision_id
      from atlas_dispatch.dispatch_stops ds
      where ds.dispatch_trip_id = v_trip_id
    ) order by drlr.dispatch_requirement_line_revision_id for key share;

  perform 1 from atlas_procurement.fulfilment_allocations fa
    where fa.fulfilment_allocation_id in (
      select far.fulfilment_allocation_id
      from atlas_dispatch.dispatch_plan_requirements dpr
      join atlas_procurement.fulfilment_allocation_revisions far
        on far.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
      where dpr.dispatch_plan_id = v_plan_id
        and dpr.dispatch_requirement_revision_id in (
          select ds.dispatch_requirement_revision_id
          from atlas_dispatch.dispatch_stops ds
          where ds.dispatch_trip_id = v_trip_id
        )
    ) order by fa.fulfilment_allocation_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_revisions far
    where far.fulfilment_allocation_revision_id in (
      select dpr.fulfilment_allocation_revision_id
      from atlas_dispatch.dispatch_plan_requirements dpr
      where dpr.dispatch_plan_id = v_plan_id
        and dpr.dispatch_requirement_revision_id in (
          select ds.dispatch_requirement_revision_id
          from atlas_dispatch.dispatch_stops ds
          where ds.dispatch_trip_id = v_trip_id
        )
    ) order by far.fulfilment_allocation_revision_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_lines fal
    where fal.fulfilment_allocation_id in (
      select far.fulfilment_allocation_id
      from atlas_dispatch.dispatch_plan_requirements dpr
      join atlas_procurement.fulfilment_allocation_revisions far
        on far.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
      where dpr.dispatch_plan_id = v_plan_id
        and dpr.dispatch_requirement_revision_id in (
          select ds.dispatch_requirement_revision_id
          from atlas_dispatch.dispatch_stops ds
          where ds.dispatch_trip_id = v_trip_id
        )
    ) order by fal.fulfilment_allocation_line_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
    where falr.fulfilment_allocation_revision_id in (
      select dpr.fulfilment_allocation_revision_id
      from atlas_dispatch.dispatch_plan_requirements dpr
      where dpr.dispatch_plan_id = v_plan_id
        and dpr.dispatch_requirement_revision_id in (
          select ds.dispatch_requirement_revision_id
          from atlas_dispatch.dispatch_stops ds
          where ds.dispatch_trip_id = v_trip_id
        )
    ) order by falr.fulfilment_allocation_line_revision_id for key share;

  -- Dispatch locks finish with parent roots before all selected children.
  perform 1 from atlas_dispatch.dispatch_plans dp
    where dp.dispatch_plan_id = v_plan_id for key share;
  perform 1 from atlas_dispatch.dispatch_plan_requirements dpr
    where dpr.dispatch_plan_id = v_plan_id
      and dpr.dispatch_requirement_revision_id in (
        select ds.dispatch_requirement_revision_id
        from atlas_dispatch.dispatch_stops ds
        where ds.dispatch_trip_id = v_trip_id
      ) order by dpr.dispatch_plan_requirement_id for key share;
  perform 1 from atlas_dispatch.dispatch_trips dt
    where dt.dispatch_trip_id = v_trip_id for update;
  perform 1 from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = v_trip_id
    order by ds.dispatch_stop_id for update;
  perform 1 from atlas_dispatch.dispatch_loads dl
    where dl.dispatch_trip_id = v_trip_id
    order by dl.dispatch_load_id for update;
  perform 1 from atlas_dispatch.dispatch_load_lines dll
    where dll.dispatch_load_id in (
      select dl.dispatch_load_id from atlas_dispatch.dispatch_loads dl
      where dl.dispatch_trip_id = v_trip_id
    ) or dll.dispatch_stop_id in (
      select ds.dispatch_stop_id from atlas_dispatch.dispatch_stops ds
      where ds.dispatch_trip_id = v_trip_id
    ) order by dll.dispatch_load_line_id for update;
  perform 1 from atlas_dispatch.delivery_confirmations dc
    where dc.dispatch_stop_id in (
      select ds.dispatch_stop_id from atlas_dispatch.dispatch_stops ds
      where ds.dispatch_trip_id = v_trip_id
    ) order by dc.delivery_confirmation_id for update;
  perform 1 from atlas_dispatch.delivery_confirmation_lines dcl
    where dcl.delivery_confirmation_id in (
      select dc.delivery_confirmation_id
      from atlas_dispatch.delivery_confirmations dc
      join atlas_dispatch.dispatch_stops ds
        on ds.dispatch_stop_id = dc.dispatch_stop_id
      where ds.dispatch_trip_id = v_trip_id
    ) or dcl.dispatch_load_line_id in (
      select dll.dispatch_load_line_id
      from atlas_dispatch.dispatch_load_lines dll
      join atlas_dispatch.dispatch_loads dl
        on dl.dispatch_load_id = dll.dispatch_load_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by dcl.delivery_confirmation_line_id for update;

  v_locked_actor_context := atlas_core.pa_05b_resolve_actor(
    request, 'DISPATCH', v_command_name
  );
  if v_locked_actor_context ? 'error'
     or atlas_core.pa_05b_safe_uuid(v_locked_actor_context ->> 'actor_id') is distinct from v_actor_id then
    raise exception using errcode = '40001', message = 'PA-05B-H3 actor identity changed after authorization.';
  end if;

  v_locked_signature := atlas_core.pa_05b_h3_trip_closure_signature(
    v_trip_id, v_completed_at
  );
  if v_locked_signature is distinct from v_signature then
    raise exception using errcode = '40001', message = 'PA-05B-H3 closure lineage changed before deterministic locks.';
  end if;

  if not exists (
    select 1
    from atlas_core.actor_role_memberships arm
    join atlas_core.roles r on r.role_id = arm.role_id
    join atlas_core.role_capabilities rc on rc.role_id = r.role_id
    join atlas_core.capabilities c on c.capability_id = rc.capability_id
    where arm.actor_id = v_actor_id
      and arm.membership_status = 'ACTIVE'
      and arm.effective_from <= pg_catalog.transaction_timestamp()
      and (arm.effective_to is null or arm.effective_to > pg_catalog.transaction_timestamp())
      and r.role_status = 'ACTIVE'
      and c.capability_code = 'dispatch_trip.close_successful'
      and c.owning_domain = 'DISPATCH'
      and c.capability_status = 'ACTIVE'
  ) then
    raise exception using errcode = '40001', message = 'PA-05B-H3 capability changed after authorization.';
  end if;

  if v_raw_stop_count = 0 then
    v_authorization_error := atlas_core.pa_05b_authorize_actor(
      request, v_actor_id, 'dispatch_trip.close_successful',
      'DISPATCH', v_command_name, null, null, v_trip_id
    );
    if v_authorization_error is not null then
      raise exception using errcode = '40001', message = 'PA-05B-H3 trip scope changed after authorization.';
    end if;
  else
    for v_row in
      select distinct dr.customer_id, dr.delivery_location_id
      from atlas_dispatch.dispatch_stops ds
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
      where ds.dispatch_trip_id = v_trip_id
      order by dr.customer_id, dr.delivery_location_id
    loop
      v_authorization_error := atlas_core.pa_05b_authorize_actor(
        request, v_actor_id, 'dispatch_trip.close_successful',
        'DISPATCH', v_command_name, v_row.customer_id,
        v_row.delivery_location_id, v_trip_id
      );
      if v_authorization_error is not null then
        raise exception using errcode = '40001', message = 'PA-05B-H3 destination scope changed after authorization.';
      end if;
    end loop;
  end if;

  v_trip_status := v_locked_signature #>> '{trip,trip_status}';
  v_departed_at := atlas_core.pa_05b_safe_timestamptz(
    v_locked_signature #>> '{trip,departed_at}'
  );
  v_current_completed_at := atlas_core.pa_05b_safe_timestamptz(
    v_locked_signature #>> '{trip,completed_at}'
  );
  v_current_version := atlas_core.pa_05b_safe_bigint(
    v_locked_signature #>> '{trip,version}'
  );
  v_driver_actor_id := atlas_core.pa_05b_safe_uuid(
    v_locked_signature #>> '{trip,driver_actor_id}'
  );
  v_driver_actor_type := v_locked_signature #>> '{trip,driver_actor_type}';
  v_driver_actor_status := v_locked_signature #>> '{trip,driver_actor_status}';
  v_vehicle_reference := v_locked_signature #>> '{trip,vehicle_reference}';

  if v_current_version is distinct from v_expected_version then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION',
      'The Dispatch Trip changed. Refresh and review before closing it.',
      'DISPATCH', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_trip_id), v_current_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_trip_status <> 'DELIVERED'
     or v_departed_at is null
     or v_current_completed_at is not null
     or v_completed_at < v_departed_at
     or (
       v_driver_actor_id is null
       and pg_catalog.btrim(coalesce(v_vehicle_reference, '')) = ''
     )
     or (
       v_driver_actor_id is not null
       and (
         v_driver_actor_status is distinct from 'ACTIVE'
         or v_driver_actor_type not in ('HUMAN', 'DELEGATED_DRIVER')
       )
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'TRIP_NOT_READY',
      'Successful closure requires one delivered, departed, uncompleted, validly assigned trip and a valid completion time.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  v_raw_stop_count := atlas_core.pa_05b_safe_bigint(
    v_locked_signature ->> 'raw_stop_count'
  );
  if v_raw_stop_count < 1
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'membership_row_count') <> v_raw_stop_count
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'valid_stop_count') <> v_raw_stop_count
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'distinct_membership_count') <> v_raw_stop_count
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'raw_load_count') <> v_raw_stop_count
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'valid_load_count') <> v_raw_stop_count
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'raw_confirmation_count') <> v_raw_stop_count
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'valid_confirmation_count') <> v_raw_stop_count
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'confirmation_successor_count') <> 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'TRIP_RECONCILIATION_FAILED',
      'Every and only exact trip stop, membership, confirmed load, and successful confirmation must reconcile.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'planning_line_count') < 1
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'planning_line_count')
        <> atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'allocation_line_count')
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'planning_line_count')
        <> atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'valid_source_line_count')
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'planning_line_count')
        <> atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'raw_load_line_count')
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'planning_line_count')
        <> atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'valid_load_line_count')
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'planning_line_count')
        <> atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'raw_confirmation_line_count')
     or atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'planning_line_count')
        <> atlas_core.pa_05b_safe_bigint(v_locked_signature ->> 'valid_confirmation_line_count')
     or atlas_core.pa_05b_safe_timestamptz(v_locked_signature ->> 'max_confirmation_at') > v_completed_at then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DELIVERY_RECONCILIATION_FAILED',
      'Every Planning, allocation, load, and successful-delivery line must reconcile exactly by identity, item, unit, and quantity.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  update atlas_dispatch.dispatch_trips dt
  set completed_at = v_completed_at,
      version = dt.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where dt.dispatch_trip_id = v_trip_id
    and dt.trip_status = 'DELIVERED'
    and dt.departed_at is not null
    and dt.completed_at is null
    and dt.version = v_expected_version
  returning dt.version into v_new_version;

  if not found then
    raise exception using errcode = '40001', message = 'PA-05B-H3 trip changed before closure update.';
  end if;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version, command_receipt_id, command_id, correlation_id,
    actor_id, occurred_at, payload_summary
  ) values (
    'SuccessfulDispatchTripClosed', 'DISPATCH', 'DispatchTrip', v_trip_id,
    v_new_version, v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id, pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'completed_at', v_completed_at,
      'trip_status', 'DELIVERED',
      'stop_count', v_raw_stop_count,
      'line_count', atlas_core.pa_05b_safe_bigint(
        v_locked_signature ->> 'planning_line_count'
      )
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version_before, aggregate_version_after,
    command_receipt_id, command_id, correlation_id, actor_id,
    reason_code, reason_note, before_summary, after_summary,
    source_interface, occurred_at
  ) values (
    'SuccessfulDispatchTripClosed', 'DISPATCH', 'DispatchTrip', v_trip_id,
    v_current_version, v_new_version, v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id, request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object(
      'trip_status', 'DELIVERED', 'completed_at', null,
      'version', v_current_version
    ),
    pg_catalog.jsonb_build_object(
      'trip_status', 'DELIVERED', 'completed_at', v_completed_at,
      'version', v_new_version
    ),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'dispatch_trip_id', v_trip_id
    ),
    'completed_at', v_completed_at,
    'new_versions', pg_catalog.jsonb_build_object(
      'dispatch_trip_version', v_new_version
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Successful Dispatch Trip closure recorded.',
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The trip changed during closure. Retry the exact request.',
      'DISPATCH', v_command_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'The successful Dispatch Trip could not be closed safely.',
      'DISPATCH', v_command_name
    );
end;
$$;

-- Revoke first, then expose exactly the reviewed eighteenth Atlas API entry.
revoke execute on function atlas_api.close_successful_trip(jsonb)
from public, anon, authenticated, service_role;
grant execute on function atlas_api.close_successful_trip(jsonb)
to authenticated;

comment on function atlas_api.close_successful_trip(jsonb) is
  'PA-05B-H3.v1 closes one fully delivered and exactly reconciled Dispatch Trip while preserving DELIVERED status.';

reset role;
revoke create on schema atlas_api from atlas_dispatch_command_runtime;
revoke atlas_dispatch_command_runtime from postgres;

grant usage on schema atlas_api to authenticated;

comment on function atlas_core.pa_05b_h3_trip_closure_signature(uuid, timestamptz) is
  'PA-05B-H3 private exact trip, stop, membership, load, and successful-delivery reconciliation signature.';
comment on role atlas_dispatch_command_runtime is
  'NOLOGIN NOINHERIT SECURITY DEFINER owner for the three PA-05B-H2 execution commands, two PA-05F setup commands, and PA-05B-H3 successful closure.';
comment on schema atlas_api is
  'Function-only Atlas Data API boundary; exactly 18 reviewed functions through PA-05B-H3.';
