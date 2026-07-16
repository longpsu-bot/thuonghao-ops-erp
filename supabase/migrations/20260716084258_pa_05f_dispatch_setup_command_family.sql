-- PA-05F: bounded Dispatch setup command family for supplier-direct Slice 1.
--
-- This migration adds exactly two public commands and one command-specific
-- validator/readiness helper. It reuses the hardened PA-05B-H1 Dispatch
-- runtime and the existing PA-04 Dispatch setup facts.

create or replace function atlas_core.pa_05f_validate_command_request(
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
  v_requested_at timestamptz;
  v_item jsonb;
  v_count integer;
  v_allowed_keys constant text[] := array[
    'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
    'expected_version', 'requested_by_auth_subject', 'requested_at',
    'reason_code', 'reason_note', 'payload'
  ];
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb), 'VALIDATION_FAILED',
      'The command request must be a JSON object.', 'DISPATCH', command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'request', 'message', 'A JSON object is required.')
      )
    );
  end if;

  if not (request ?& v_allowed_keys) or request - v_allowed_keys <> '{}'::jsonb then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'request', 'message', 'Use exactly the PA-05F command-envelope fields.'
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from 'PA-05F.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use PA-05F.v1.')
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
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0 then
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
  if not (request ? 'reason_note') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'reason_note', 'message', 'The reason_note field is required and may be null.')
    );
  end if;

  v_payload := request -> 'payload';
  if v_payload is null or pg_catalog.jsonb_typeof(v_payload) <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'A JSON object is required.')
    );
  elsif command_name = 'create_dispatch_plan' then
    if not (v_payload ?& array['plan_reference', 'dispatch_wave', 'requirements'])
       or v_payload - array['plan_reference', 'dispatch_wave', 'requirements'] <> '{}'::jsonb
       or pg_catalog.btrim(coalesce(v_payload ->> 'plan_reference', '')) = ''
       or pg_catalog.length(pg_catalog.btrim(v_payload ->> 'plan_reference')) > 200
       or (
         pg_catalog.jsonb_typeof(v_payload -> 'dispatch_wave') <> 'null'
         and (
           pg_catalog.jsonb_typeof(v_payload -> 'dispatch_wave') <> 'string'
           or pg_catalog.btrim(coalesce(v_payload ->> 'dispatch_wave', '')) = ''
           or pg_catalog.length(pg_catalog.btrim(v_payload ->> 'dispatch_wave')) > 100
         )
       )
       or pg_catalog.jsonb_typeof(v_payload -> 'requirements') <> 'array' then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Use the exact PA-05F Dispatch Plan payload.')
      );
    end if;

    if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is distinct from 1 then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'expected_version', 'message', 'A new Dispatch Plan requires expected_version 1.')
      );
    end if;

    if pg_catalog.jsonb_typeof(v_payload -> 'requirements') = 'array' then
      v_count := pg_catalog.jsonb_array_length(v_payload -> 'requirements');
      if v_count < 1 or v_count > 100 then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.requirements', 'message', 'Provide 1 to 100 requirements.')
        );
      end if;

      for v_item in select value from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') loop
        if pg_catalog.jsonb_typeof(v_item) <> 'object'
           or not (v_item ?& array[
             'dispatch_requirement_revision_id', 'fulfilment_allocation_revision_id',
             'expected_dispatch_requirement_version', 'expected_fulfilment_allocation_version'
           ])
           or v_item - array[
             'dispatch_requirement_revision_id', 'fulfilment_allocation_revision_id',
             'expected_dispatch_requirement_version', 'expected_fulfilment_allocation_version'
           ] <> '{}'::jsonb
           or atlas_core.pa_05b_safe_uuid(v_item ->> 'dispatch_requirement_revision_id') is null
           or atlas_core.pa_05b_safe_uuid(v_item ->> 'fulfilment_allocation_revision_id') is null
           or coalesce(atlas_core.pa_05b_safe_bigint(v_item ->> 'expected_dispatch_requirement_version'), 0) <= 0
           or coalesce(atlas_core.pa_05b_safe_bigint(v_item ->> 'expected_fulfilment_allocation_version'), 0) <= 0 then
          v_errors := v_errors || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('field', 'payload.requirements', 'message', 'Every requirement must use the exact valid PA-05F shape.')
          );
        end if;
      end loop;

      if exists (
        select 1 from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
        group by atlas_core.pa_05b_safe_uuid(item ->> 'dispatch_requirement_revision_id')
        having count(*) > 1
      ) or exists (
        select 1 from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
        group by atlas_core.pa_05b_safe_uuid(item ->> 'fulfilment_allocation_revision_id')
        having count(*) > 1
      ) or exists (
        select 1 from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
        group by atlas_core.pa_05b_safe_uuid(item ->> 'dispatch_requirement_revision_id'),
                 atlas_core.pa_05b_safe_uuid(item ->> 'fulfilment_allocation_revision_id')
        having count(*) > 1
      ) then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.requirements', 'message', 'Requirement revisions, allocation revisions, and exact pairs must be unique.')
        );
      end if;
    end if;
  elsif command_name = 'create_or_assign_dispatch_trip' then
    if not (v_payload ?& array[
         'dispatch_plan_id', 'trip_reference', 'driver_actor_id',
         'vehicle_reference', 'planned_departure_at', 'stops'
       ])
       or v_payload - array[
         'dispatch_plan_id', 'trip_reference', 'driver_actor_id',
         'vehicle_reference', 'planned_departure_at', 'stops'
       ] <> '{}'::jsonb
       or atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_plan_id') is null
       or pg_catalog.btrim(coalesce(v_payload ->> 'trip_reference', '')) = ''
       or pg_catalog.length(pg_catalog.btrim(v_payload ->> 'trip_reference')) > 200
       or (
         pg_catalog.jsonb_typeof(v_payload -> 'driver_actor_id') <> 'null'
         and atlas_core.pa_05b_safe_uuid(v_payload ->> 'driver_actor_id') is null
       )
       or (
         pg_catalog.jsonb_typeof(v_payload -> 'vehicle_reference') <> 'null'
         and (
           pg_catalog.jsonb_typeof(v_payload -> 'vehicle_reference') <> 'string'
           or pg_catalog.btrim(coalesce(v_payload ->> 'vehicle_reference', '')) = ''
           or pg_catalog.length(pg_catalog.btrim(v_payload ->> 'vehicle_reference')) > 200
         )
       )
       or (
         pg_catalog.jsonb_typeof(v_payload -> 'planned_departure_at') <> 'null'
         and atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'planned_departure_at') is null
       )
       or pg_catalog.jsonb_typeof(v_payload -> 'stops') <> 'array' then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Use the exact PA-05F assigned-trip payload.')
      );
    end if;

    if atlas_core.pa_05b_safe_uuid(v_payload ->> 'driver_actor_id') is null
       and pg_catalog.btrim(coalesce(v_payload ->> 'vehicle_reference', '')) = '' then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Provide an active driver and/or a vehicle reference.')
      );
    end if;

    if pg_catalog.jsonb_typeof(v_payload -> 'stops') = 'array' then
      v_count := pg_catalog.jsonb_array_length(v_payload -> 'stops');
      if v_count < 1 or v_count > 100 then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.stops', 'message', 'Provide 1 to 100 stops.')
        );
      end if;

      for v_item in select value from pg_catalog.jsonb_array_elements(v_payload -> 'stops') loop
        if pg_catalog.jsonb_typeof(v_item) <> 'object'
           or not (v_item ?& array['dispatch_plan_requirement_id', 'stop_sequence'])
           or v_item - array['dispatch_plan_requirement_id', 'stop_sequence'] <> '{}'::jsonb
           or atlas_core.pa_05b_safe_uuid(v_item ->> 'dispatch_plan_requirement_id') is null
           or coalesce(atlas_core.pa_05b_safe_bigint(v_item ->> 'stop_sequence'), 0) <= 0
           or coalesce(atlas_core.pa_05b_safe_bigint(v_item ->> 'stop_sequence'), 2147483648) > 2147483647 then
          v_errors := v_errors || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('field', 'payload.stops', 'message', 'Every stop must use one membership ID and one positive integer sequence.')
          );
        end if;
      end loop;

      if exists (
        select 1 from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
        group by atlas_core.pa_05b_safe_uuid(item ->> 'dispatch_plan_requirement_id')
        having count(*) > 1
      ) or exists (
        select 1 from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
        group by atlas_core.pa_05b_safe_bigint(item ->> 'stop_sequence')
        having count(*) > 1
      ) or exists (
        select 1
        from (
          select pg_catalog.min(atlas_core.pa_05b_safe_bigint(item ->> 'stop_sequence')) as minimum_sequence,
                 pg_catalog.max(atlas_core.pa_05b_safe_bigint(item ->> 'stop_sequence')) as maximum_sequence,
                 count(*)::bigint as sequence_count
          from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
        ) sequences
        where sequences.minimum_sequence <> 1
           or sequences.maximum_sequence <> sequences.sequence_count
      ) then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.stops', 'message', 'Membership IDs must be unique and stop sequences must be unique and contiguous from 1.')
        );
      end if;
    end if;
  else
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'command_name', 'message', 'The PA-05F command is not supported.')
    );
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The PA-05F command request is invalid.',
      'DISPATCH', command_name, false, v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_api.create_dispatch_plan(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'create_dispatch_plan';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_plan_reference text;
  v_dispatch_wave text;
  v_item_count integer;
  v_resolved_count integer;
  v_service_date_count integer;
  v_service_date date;
  v_dispatch_plan_id uuid;
  v_dispatch_plan_requirement_id uuid;
  v_membership_ids jsonb := '[]'::jsonb;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_row record;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05f_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;

  v_plan_reference := pg_catalog.btrim(v_payload ->> 'plan_reference');
  v_dispatch_wave := case
    when pg_catalog.jsonb_typeof(v_payload -> 'dispatch_wave') = 'null' then null
    else pg_catalog.btrim(v_payload ->> 'dispatch_wave')
  end;
  v_item_count := pg_catalog.jsonb_array_length(v_payload -> 'requirements');

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'DISPATCH', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  -- Resolve every exact pair to its authoritative Planning destination before
  -- receipt registration. A missing or cross-wired pair cannot create a receipt.
  with submitted as (
    select atlas_core.pa_05b_safe_uuid(item ->> 'dispatch_requirement_revision_id') as requirement_revision_id,
           atlas_core.pa_05b_safe_uuid(item ->> 'fulfilment_allocation_revision_id') as allocation_revision_id
    from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
  )
  select count(*)::integer into v_resolved_count
  from submitted s
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_revision_id = s.requirement_revision_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = drr.dispatch_requirement_id
  join atlas_procurement.fulfilment_allocation_revisions far
    on far.fulfilment_allocation_revision_id = s.allocation_revision_id
  join atlas_procurement.fulfilment_allocations fa
    on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
   and fa.dispatch_requirement_id = dr.dispatch_requirement_id
  join atlas_admin.delivery_locations loc
    on loc.delivery_location_id = dr.delivery_location_id
   and loc.customer_id = dr.customer_id;

  if v_resolved_count <> v_item_count then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'Every submitted requirement/allocation pair must resolve to one authoritative Planning destination.',
      'DISPATCH', v_command_name
    );
  end if;

  for v_row in
    with submitted as (
      select atlas_core.pa_05b_safe_uuid(item ->> 'dispatch_requirement_revision_id') as requirement_revision_id,
             atlas_core.pa_05b_safe_uuid(item ->> 'fulfilment_allocation_revision_id') as allocation_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
    )
    select distinct dr.customer_id, dr.delivery_location_id
    from submitted s
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = s.requirement_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    order by dr.customer_id, dr.delivery_location_id
  loop
    v_error := atlas_core.pa_05b_authorize_actor(
      request, v_actor_id, 'dispatch_plan.create', 'DISPATCH', v_command_name,
      v_row.customer_id, v_row.delivery_location_id, null
    );
    if v_error is not null then return v_error; end if;
  end loop;

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'DISPATCH',
    'plan-reference:' || v_plan_reference
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  -- Lock the initiating actor's security facts before domain references. These
  -- UPDATE privileges remain lock-only because no UPDATE policy is added.
  perform 1 from atlas_core.actors a
    where a.actor_id = v_actor_id for key share;
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
  perform 1 from atlas_core.capabilities cap
    where cap.capability_id in (
      select rc.capability_id
      from atlas_core.role_capabilities rc
      join atlas_core.actor_role_memberships arm on arm.role_id = rc.role_id
      where arm.actor_id = v_actor_id
    ) order by cap.capability_id for key share;
  perform 1 from atlas_core.actor_scopes s
    where s.actor_id = v_actor_id
    order by s.actor_scope_id for key share;

  -- Admin references first.
  perform 1 from atlas_admin.customers c
    where c.customer_id in (
      select dr.customer_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    ) order by c.customer_id for key share;
  perform 1 from atlas_admin.delivery_locations loc
    where loc.delivery_location_id in (
      select dr.delivery_location_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    ) order by loc.delivery_location_id for key share;
  perform 1 from atlas_admin.suppliers sup
    where sup.supplier_id in (
      select falr.supplier_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
    ) order by sup.supplier_id for key share;
  perform 1 from atlas_admin.ingredients i
    where i.ingredient_id in (
      select drlr.ingredient_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
    ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (
      select drlr.unit_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
    ) order by u.unit_id for key share;

  -- Stable requirement and allocation roots serialize competing admissions.
  perform 1 from atlas_planning.dispatch_requirements dr
    where dr.dispatch_requirement_id in (
      select drr.dispatch_requirement_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
    ) order by dr.dispatch_requirement_id for update;
  perform 1 from atlas_planning.dispatch_requirement_revisions drr
    where drr.dispatch_requirement_revision_id in (
      select (item ->> 'dispatch_requirement_revision_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
    ) order by drr.dispatch_requirement_revision_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_lines drl
    where drl.dispatch_requirement_id in (
      select drr.dispatch_requirement_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
    ) order by drl.dispatch_requirement_line_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_line_revisions drlr
    where drlr.dispatch_requirement_revision_id in (
      select (item ->> 'dispatch_requirement_revision_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
    ) order by drlr.dispatch_requirement_line_revision_id for key share;

  for v_row in
    select distinct dr.customer_id, dr.delivery_location_id
    from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    order by dr.customer_id, dr.delivery_location_id
  loop
    v_error := atlas_core.pa_05b_authorize_actor(
      request, v_actor_id, 'dispatch_plan.create', 'DISPATCH', v_command_name,
      v_row.customer_id, v_row.delivery_location_id, null
    );
    if v_error is not null then
      raise exception using errcode = '40001',
        message = 'dispatch plan authorization scope changed after receipt registration';
    end if;
  end loop;

  perform 1 from atlas_planning.wholesale_orders wo
    where wo.wholesale_order_id in (
      select cnb.wholesale_order_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb
        on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      join atlas_planning.confirmed_need_batches cnb
        on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
    ) order by wo.wholesale_order_id for key share;
  perform 1 from atlas_planning.wholesale_order_lines wol
    where wol.wholesale_order_id in (
      select cnb.wholesale_order_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb
        on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      join atlas_planning.confirmed_need_batches cnb
        on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
    ) order by wol.wholesale_order_line_id for key share;
  perform 1 from atlas_planning.wholesale_order_line_revisions wolr
    where wolr.wholesale_order_line_revision_id in (
      select pdr.wholesale_order_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.purchase_demand_references pdr
        on pdr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    ) order by wolr.wholesale_order_line_revision_id for key share;
  perform 1 from atlas_planning.confirmed_need_batches cnb
    where cnb.confirmed_need_batch_id in (
      select phb.confirmed_need_batch_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb
        on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
    ) order by cnb.confirmed_need_batch_id for key share;
  perform 1 from atlas_planning.confirmed_need_lines cnl
    where cnl.confirmed_need_line_id in (
      select phl.confirmed_need_line_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.dispatch_requirement_lines drl
        on drl.dispatch_requirement_id = drr.dispatch_requirement_id
      join atlas_planning.purchase_handoff_lines phl
        on phl.purchase_handoff_line_id = drl.purchase_handoff_line_id
    ) order by cnl.confirmed_need_line_id for key share;
  perform 1 from atlas_planning.confirmed_need_line_revisions cnlr
    where cnlr.confirmed_need_line_revision_id in (
      select phlr.confirmed_need_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.purchase_handoff_line_revisions phlr
        on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    ) order by cnlr.confirmed_need_line_revision_id for key share;
  perform 1 from atlas_planning.confirmed_need_approval_snapshots cns
    where cns.confirmed_need_approval_snapshot_id in (
      select cnsl.confirmed_need_approval_snapshot_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.purchase_demand_references pdr
        on pdr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
      join atlas_planning.confirmed_need_snapshot_lines cnsl
        on cnsl.confirmed_need_snapshot_line_id = pdr.confirmed_need_snapshot_line_id
    ) order by cns.confirmed_need_approval_snapshot_id for key share;
  perform 1 from atlas_planning.confirmed_need_snapshot_lines cnsl
    where cnsl.confirmed_need_snapshot_line_id in (
      select pdr.confirmed_need_snapshot_line_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.purchase_demand_references pdr
        on pdr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    ) order by cnsl.confirmed_need_snapshot_line_id for key share;

  perform 1 from atlas_planning.purchase_handoff_revisions phr
    where phr.purchase_handoff_revision_id in (
      select drr.purchase_handoff_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
    ) order by phr.purchase_handoff_revision_id for key share;
  perform 1 from atlas_planning.purchase_handoff_batches phb
    where phb.purchase_handoff_batch_id in (
      select phr.purchase_handoff_batch_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
    ) order by phb.purchase_handoff_batch_id for key share;
  perform 1 from atlas_planning.purchase_handoff_lines phl
    where phl.purchase_handoff_line_id in (
      select drl.purchase_handoff_line_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
      join atlas_planning.dispatch_requirement_lines drl
        on drl.dispatch_requirement_id = drr.dispatch_requirement_id
    ) order by phl.purchase_handoff_line_id for key share;
  perform 1 from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_revision_id in (
      select drr.purchase_handoff_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
    ) order by phlr.purchase_handoff_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_demand_references pdr
    where pdr.purchase_handoff_line_revision_id in (
      select drlr.purchase_handoff_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
    ) order by pdr.purchase_demand_reference_id for key share;

  perform 1 from atlas_procurement.fulfilment_allocations fa
    where fa.fulfilment_allocation_id in (
      select far.fulfilment_allocation_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_procurement.fulfilment_allocation_revisions far
        on far.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
    ) order by fa.fulfilment_allocation_id for update;
  perform 1 from atlas_procurement.fulfilment_allocation_revisions far
    where far.fulfilment_allocation_revision_id in (
      select (item ->> 'fulfilment_allocation_revision_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
    ) order by far.fulfilment_allocation_revision_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_lines fal
    where fal.fulfilment_allocation_id in (
      select far.fulfilment_allocation_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_procurement.fulfilment_allocation_revisions far
        on far.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
    ) order by fal.fulfilment_allocation_line_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
    where falr.fulfilment_allocation_revision_id in (
      select (item ->> 'fulfilment_allocation_revision_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
    ) order by falr.fulfilment_allocation_line_revision_id for key share;
  perform 1 from atlas_procurement.purchase_orders po
    where po.purchase_order_id in (
      select pol.purchase_order_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
      join atlas_procurement.purchase_order_lines pol
        on pol.fulfilment_allocation_line_id = falr.fulfilment_allocation_line_id
    ) order by po.purchase_order_id for key share;
  perform 1 from atlas_procurement.purchase_order_revisions por
    where por.purchase_order_id in (
      select pol.purchase_order_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
      join atlas_procurement.purchase_order_lines pol
        on pol.fulfilment_allocation_line_id = falr.fulfilment_allocation_line_id
    ) order by por.purchase_order_revision_id for key share;
  perform 1 from atlas_procurement.purchase_order_lines pol
    where pol.fulfilment_allocation_line_id in (
      select falr.fulfilment_allocation_line_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
    ) order by pol.purchase_order_line_id for key share;
  perform 1 from atlas_procurement.purchase_order_line_revisions polr
    where polr.fulfilment_allocation_line_revision_id in (
      select falr.fulfilment_allocation_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
    ) order by polr.purchase_order_line_revision_id for key share;

  perform 1 from atlas_evidence.supplier_receiving_evidence sre
    where sre.supplier_receiving_evidence_id in (
      select ea.supplier_receiving_evidence_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
      join atlas_evidence.evidence_applications ea
        on ea.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
    ) order by sre.supplier_receiving_evidence_id for key share;
  perform 1 from atlas_evidence.evidence_applications ea
    where ea.fulfilment_allocation_line_revision_id in (
      select falr.fulfilment_allocation_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
    ) order by ea.evidence_application_id for key share;

  -- Dispatch-side conflicts and references are serialized after source facts.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('PA-05F:PLAN:' || v_plan_reference, 0)
  );
  perform 1 from atlas_dispatch.dispatch_plans dp
    where dp.plan_reference = v_plan_reference
    order by dp.dispatch_plan_id for key share;
  perform 1 from atlas_dispatch.dispatch_plan_requirements dpr
    where (dpr.dispatch_requirement_revision_id, dpr.fulfilment_allocation_revision_id) in (
      select (item ->> 'dispatch_requirement_revision_id')::uuid,
             (item ->> 'fulfilment_allocation_revision_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
    ) order by dpr.dispatch_plan_requirement_id for key share;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    join atlas_procurement.fulfilment_allocation_revisions far
      on far.fulfilment_allocation_revision_id = (item ->> 'fulfilment_allocation_revision_id')::uuid
    join atlas_procurement.fulfilment_allocations fa
      on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
    where dr.version <> (item ->> 'expected_dispatch_requirement_version')::bigint
       or fa.version <> (item ->> 'expected_fulfilment_allocation_version')::bigint
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION',
      'A selected requirement or allocation changed. Refresh and review before creating the Dispatch Plan.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(distinct dr.service_date)::integer, pg_catalog.min(dr.service_date)
    into v_service_date_count, v_service_date
  from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_revision_id = (item ->> 'dispatch_requirement_revision_id')::uuid
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = drr.dispatch_requirement_id;

  if v_service_date_count <> 1
     or exists (
       select 1
       from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
       where not atlas_core.pa_05f_dispatch_pair_is_ready(
         (item ->> 'dispatch_requirement_revision_id')::uuid,
         (item ->> 'fulfilment_allocation_revision_id')::uuid
       )
     )
     or exists (
       select 1
       from atlas_dispatch.dispatch_plan_requirements dpr
       join atlas_dispatch.dispatch_plans dp
         on dp.dispatch_plan_id = dpr.dispatch_plan_id
       where dp.plan_status <> 'CANCELLED'
         and (dpr.dispatch_requirement_revision_id, dpr.fulfilment_allocation_revision_id) in (
           select (item ->> 'dispatch_requirement_revision_id')::uuid,
                  (item ->> 'fulfilment_allocation_revision_id')::uuid
           from pg_catalog.jsonb_array_elements(v_payload -> 'requirements') item
         )
     )
     or exists (
       select 1 from atlas_dispatch.dispatch_plans dp
       where dp.plan_reference = v_plan_reference
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'Dispatch Plan creation requires unused, same-date, fully evidenced, exact current requirement/allocation pairs.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  begin
    insert into atlas_dispatch.dispatch_plans (
      plan_reference, service_date, dispatch_wave, plan_status, version,
      created_by_actor_id
    ) values (
      v_plan_reference, v_service_date, v_dispatch_wave, 'PLANNED', 1,
      v_actor_id
    ) returning dispatch_plan_id into v_dispatch_plan_id;

    for v_row in
      select (item ->> 'dispatch_requirement_revision_id')::uuid as requirement_revision_id,
             (item ->> 'fulfilment_allocation_revision_id')::uuid as allocation_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'requirements')
        with ordinality submitted(item, item_order)
      order by item_order
    loop
      insert into atlas_dispatch.dispatch_plan_requirements (
        dispatch_plan_id, dispatch_requirement_revision_id,
        fulfilment_allocation_revision_id
      ) values (
        v_dispatch_plan_id, v_row.requirement_revision_id,
        v_row.allocation_revision_id
      ) returning dispatch_plan_requirement_id
        into v_dispatch_plan_requirement_id;
      v_membership_ids := v_membership_ids ||
        pg_catalog.jsonb_build_array(v_dispatch_plan_requirement_id);
    end loop;

    insert into atlas_audit.domain_events (
      event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
      command_receipt_id, command_id, correlation_id, actor_id, occurred_at,
      payload_summary
    ) values (
      'DispatchPlanCreated', 'DISPATCH', 'DispatchPlan', v_dispatch_plan_id, 1,
      v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
      pg_catalog.transaction_timestamp(),
      pg_catalog.jsonb_build_object(
        'plan_reference', v_plan_reference, 'service_date', v_service_date,
        'dispatch_wave', v_dispatch_wave, 'membership_count', v_item_count
      )
    ) returning domain_event_id into v_domain_event_id;

    insert into atlas_audit.audit_events (
      event_type, source_domain, aggregate_type, aggregate_id,
      aggregate_version_after, command_receipt_id, command_id, correlation_id,
      actor_id, reason_code, reason_note, after_summary, source_interface,
      occurred_at
    ) values (
      'DispatchPlanCreated', 'DISPATCH', 'DispatchPlan', v_dispatch_plan_id, 1,
      v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
      request ->> 'reason_code', request ->> 'reason_note',
      pg_catalog.jsonb_build_object(
        'plan_status', 'PLANNED', 'plan_reference', v_plan_reference,
        'service_date', v_service_date, 'membership_count', v_item_count
      ),
      'atlas_api', pg_catalog.transaction_timestamp()
    ) returning audit_event_id into v_audit_event_id;
  exception
    when unique_violation then
      v_error := atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'The Dispatch Plan reference or exact membership is already in use.',
        'DISPATCH', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end;

  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'dispatch_plan_id', v_dispatch_plan_id,
      'dispatch_plan_requirement_ids', v_membership_ids
    ),
    'new_versions', pg_catalog.jsonb_build_object('dispatch_plan_version', 1),
    'derived_service_date', v_service_date,
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Dispatch Plan created from fully evidenced requirements.',
    'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'DISPATCH', v_command_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'The Dispatch Plan could not be created safely.',
      'DISPATCH', v_command_name
    );
end;
$$;

-- Exact, command-specific post-lock readiness proof shared by both PA-05F
-- entry points. Callers lock the selected roots and child lineage first.
create or replace function atlas_core.pa_05f_dispatch_pair_is_ready(
  p_dispatch_requirement_revision_id uuid,
  p_fulfilment_allocation_revision_id uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
  with pair as (
    select dr.dispatch_requirement_id, dr.customer_id, dr.delivery_location_id,
           dr.service_date, drr.dispatch_requirement_revision_id,
           fa.fulfilment_allocation_id,
           far.fulfilment_allocation_revision_id
    from atlas_planning.dispatch_requirement_revisions drr
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    join atlas_procurement.fulfilment_allocation_revisions far
      on far.fulfilment_allocation_revision_id = p_fulfilment_allocation_revision_id
    join atlas_procurement.fulfilment_allocations fa
      on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
     and fa.dispatch_requirement_id = dr.dispatch_requirement_id
    join atlas_admin.customers c on c.customer_id = dr.customer_id
    join atlas_admin.delivery_locations loc
      on loc.delivery_location_id = dr.delivery_location_id
     and loc.customer_id = dr.customer_id
    where drr.dispatch_requirement_revision_id = p_dispatch_requirement_revision_id
      and dr.source_of_need = 'WHOLESALE'
      and dr.requirement_status = 'RELEASED'
      and drr.revision_status = 'RELEASED' and drr.is_current
      and drr.released_by_actor_id is not null and drr.released_at is not null
      and pg_catalog.btrim(drr.customer_name_snapshot) <> ''
      and pg_catalog.btrim(drr.location_name_snapshot) <> ''
      and pg_catalog.btrim(drr.address_snapshot) <> ''
      and pg_catalog.btrim(drr.timezone_name) <> ''
      and fa.allocation_status = 'READY_FOR_DISPATCH'
      and far.revision_status = 'READY_FOR_DISPATCH' and far.is_current
      and c.customer_type = 'WHOLESALE' and c.customer_status = 'ACTIVE'
      and loc.location_status = 'ACTIVE'
  ),
  valid_lineage as (
    select falr.fulfilment_allocation_line_revision_id,
           falr.fulfilment_allocation_line_id,
           falr.allocated_quantity, falr.unit_id, falr.supplier_id,
           drlr.dispatch_requirement_line_revision_id,
           drlr.ingredient_id,
           polr.purchase_order_line_revision_id
    from pair p
    join atlas_planning.dispatch_requirement_lines drl
      on drl.dispatch_requirement_id = p.dispatch_requirement_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.dispatch_requirement_line_id = drl.dispatch_requirement_line_id
     and drlr.dispatch_requirement_revision_id = p.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = drlr.dispatch_requirement_revision_id
     and drr.dispatch_requirement_id = drl.dispatch_requirement_id
    join atlas_planning.purchase_handoff_line_revisions phlr
      on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    join atlas_planning.purchase_handoff_lines phl
      on phl.purchase_handoff_line_id = drl.purchase_handoff_line_id
     and phl.purchase_handoff_line_id = phlr.purchase_handoff_line_id
    join atlas_planning.purchase_handoff_revisions phr
      on phr.purchase_handoff_revision_id = phlr.purchase_handoff_revision_id
     and phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
    join atlas_planning.purchase_handoff_batches phb
      on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
     and phb.purchase_handoff_batch_id = phl.purchase_handoff_batch_id
    join atlas_planning.confirmed_need_lines cnl
      on cnl.confirmed_need_line_id = phl.confirmed_need_line_id
    join atlas_planning.confirmed_need_line_revisions cnlr
      on cnlr.confirmed_need_line_revision_id = phlr.confirmed_need_line_revision_id
     and cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id
    join atlas_planning.confirmed_need_batches cnb
      on cnb.confirmed_need_batch_id = cnl.confirmed_need_batch_id
     and cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
    join atlas_planning.purchase_demand_references pdr
      on pdr.purchase_handoff_line_revision_id = phlr.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_approval_snapshots cns
      on cns.confirmed_need_batch_id = cnb.confirmed_need_batch_id
     and cns.approved_version = cnb.version
    join atlas_planning.confirmed_need_snapshot_lines cnsl
      on cnsl.confirmed_need_snapshot_line_id = pdr.confirmed_need_snapshot_line_id
     and cnsl.confirmed_need_approval_snapshot_id = cns.confirmed_need_approval_snapshot_id
     and cnsl.confirmed_need_line_revision_id = cnlr.confirmed_need_line_revision_id
    join atlas_planning.wholesale_order_line_revisions wolr
      on wolr.wholesale_order_line_revision_id = pdr.wholesale_order_line_revision_id
     and wolr.wholesale_order_line_revision_id = cnlr.wholesale_order_line_revision_id
    join atlas_planning.wholesale_order_lines wol
      on wol.wholesale_order_line_id = wolr.wholesale_order_line_id
     and wol.wholesale_order_line_id = cnl.wholesale_order_line_id
    join atlas_planning.wholesale_orders wo
      on wo.wholesale_order_id = wol.wholesale_order_id
     and wo.wholesale_order_id = cnb.wholesale_order_id
    join atlas_procurement.fulfilment_allocation_lines fal
      on fal.fulfilment_allocation_id = p.fulfilment_allocation_id
     and fal.dispatch_requirement_line_id = drl.dispatch_requirement_line_id
     and fal.portion_sequence = 1
    join atlas_procurement.fulfilment_allocation_line_revisions falr
      on falr.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
     and falr.fulfilment_allocation_revision_id = p.fulfilment_allocation_revision_id
     and falr.dispatch_requirement_line_revision_id = drlr.dispatch_requirement_line_revision_id
    join atlas_procurement.purchase_order_lines pol
      on pol.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
    join atlas_procurement.purchase_order_line_revisions polr
      on polr.purchase_order_line_id = pol.purchase_order_line_id
     and polr.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_revision_id = polr.purchase_order_revision_id
     and por.purchase_order_id = pol.purchase_order_id
     and por.revision_status = 'RELEASED_TO_SUPPLIER' and por.is_current
    join atlas_procurement.purchase_orders po
      on po.purchase_order_id = por.purchase_order_id
     and po.purchase_order_status = 'RELEASED_TO_SUPPLIER'
     and po.supplier_id = falr.supplier_id
    join atlas_admin.suppliers sup
      on sup.supplier_id = falr.supplier_id and sup.supplier_status = 'ACTIVE'
    join atlas_admin.ingredients i
      on i.ingredient_id = drlr.ingredient_id and i.ingredient_status = 'ACTIVE'
    join atlas_admin.units u
      on u.unit_id = drlr.unit_id and u.unit_status = 'ACTIVE'
    where phb.handoff_status = 'RELEASED_TO_PROCUREMENT'
      and phr.revision_status = 'RELEASED_TO_PROCUREMENT' and phr.is_current
      and cnb.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
      and cnlr.revision_status = 'RELEASED' and cnlr.is_current
      and wolr.revision_status = 'RELEASED' and wolr.is_current
      and wo.order_status = 'RELEASED'
      and falr.fulfilment_source_type = 'SUPPLIER_PO'
      and falr.line_status = 'READY_FOR_EVIDENCE'
      and por.released_by_actor_id is not null and por.released_at is not null
      and wo.customer_id = p.customer_id
      and wo.delivery_location_id = p.delivery_location_id
      and wo.service_date = p.service_date
      and phlr.delivery_location_id = p.delivery_location_id
      and phlr.service_date = p.service_date
      and por.delivery_location_id = p.delivery_location_id
      and por.service_date = p.service_date
      and polr.delivery_location_id = p.delivery_location_id
      and polr.service_date = p.service_date
      and drlr.ingredient_id = phlr.ingredient_id
      and phlr.ingredient_id = cnlr.ingredient_id
      and cnlr.ingredient_id = cnsl.ingredient_id
      and cnsl.ingredient_id = wolr.ingredient_id
      and wolr.ingredient_id = polr.ingredient_id
      and drlr.unit_id = phlr.unit_id
      and phlr.unit_id = cnlr.unit_id
      and cnlr.unit_id = cnsl.unit_id
      and cnsl.unit_id = pdr.unit_id
      and pdr.unit_id = wolr.unit_id
      and wolr.unit_id = falr.unit_id
      and falr.unit_id = polr.unit_id
      and wolr.requested_quantity = cnlr.theoretical_quantity
      and cnlr.theoretical_quantity = cnlr.confirmed_quantity
      and cnlr.confirmed_quantity = cnsl.approved_quantity
      and cnsl.approved_quantity = pdr.approved_quantity
      and pdr.approved_quantity = phlr.handoff_quantity
      and phlr.handoff_quantity = drlr.required_quantity
      and drlr.required_quantity = falr.allocated_quantity
      and falr.allocated_quantity = polr.ordered_quantity
  ),
  active_applications as (
    select ea.evidence_application_id, ea.supplier_receiving_evidence_id,
           ea.fulfilment_allocation_line_revision_id, ea.applied_quantity,
           ea.unit_id
    from atlas_evidence.evidence_applications ea
    join valid_lineage vl
      on vl.fulfilment_allocation_line_revision_id = ea.fulfilment_allocation_line_revision_id
    where ea.application_status = 'VALID'
      and not exists (
        select 1 from atlas_evidence.evidence_applications successor
        where successor.supersedes_evidence_application_id = ea.evidence_application_id
          and successor.application_status = 'VALID'
      )
  ),
  matching_applications as (
    select aa.evidence_application_id, aa.supplier_receiving_evidence_id,
           aa.fulfilment_allocation_line_revision_id, aa.applied_quantity
    from active_applications aa
    join valid_lineage vl
      on vl.fulfilment_allocation_line_revision_id = aa.fulfilment_allocation_line_revision_id
    join atlas_evidence.supplier_receiving_evidence sre
      on sre.supplier_receiving_evidence_id = aa.supplier_receiving_evidence_id
     and sre.purchase_order_line_revision_id = vl.purchase_order_line_revision_id
     and sre.supplier_id = vl.supplier_id
     and sre.ingredient_id = vl.ingredient_id
     and sre.unit_id = vl.unit_id
    where sre.evidence_status = 'VALID'
      and aa.unit_id = vl.unit_id
      and not exists (
        select 1 from atlas_evidence.supplier_receiving_evidence successor
        where successor.supersedes_evidence_id = sre.supplier_receiving_evidence_id
          and successor.evidence_status = 'VALID'
      )
  ),
  evidence_line_totals as (
    select ma.fulfilment_allocation_line_revision_id,
           count(*) as application_count,
           pg_catalog.sum(ma.applied_quantity) as applied_quantity
    from matching_applications ma
    group by ma.fulfilment_allocation_line_revision_id
  )
  select exists (
    select 1
    from pair p
    where (select count(*) from atlas_planning.dispatch_requirement_lines drl
           where drl.dispatch_requirement_id = p.dispatch_requirement_id) > 0
      and (select count(*) from atlas_planning.dispatch_requirement_lines drl
           where drl.dispatch_requirement_id = p.dispatch_requirement_id)
          = (select count(*) from atlas_planning.dispatch_requirement_line_revisions drlr
             where drlr.dispatch_requirement_revision_id = p.dispatch_requirement_revision_id)
      and (select count(*) from atlas_planning.dispatch_requirement_lines drl
           where drl.dispatch_requirement_id = p.dispatch_requirement_id)
          = (select count(*) from atlas_procurement.fulfilment_allocation_lines fal
             where fal.fulfilment_allocation_id = p.fulfilment_allocation_id)
      and (select count(*) from atlas_planning.dispatch_requirement_lines drl
           where drl.dispatch_requirement_id = p.dispatch_requirement_id)
          = (select count(*) from atlas_procurement.fulfilment_allocation_line_revisions falr
             where falr.fulfilment_allocation_revision_id = p.fulfilment_allocation_revision_id)
      and (select count(*) from atlas_planning.dispatch_requirement_lines drl
           where drl.dispatch_requirement_id = p.dispatch_requirement_id)
          = (select count(*) from valid_lineage)
      and (select count(*) from valid_lineage)
          = (select count(distinct vl.fulfilment_allocation_line_revision_id) from valid_lineage vl)
      and not exists (
        select 1 from valid_lineage vl
        left join evidence_line_totals elt
          on elt.fulfilment_allocation_line_revision_id = vl.fulfilment_allocation_line_revision_id
        where coalesce(elt.application_count, 0) < 1
           or elt.applied_quantity is distinct from vl.allocated_quantity
      )
      and (select count(*) from active_applications)
          = (select count(*) from matching_applications)
      and not exists (
        select 1
        from (
          select sre.supplier_receiving_evidence_id, sre.evidence_quantity,
                 pg_catalog.sum(ea.applied_quantity) as total_applied
          from atlas_evidence.supplier_receiving_evidence sre
          join atlas_evidence.evidence_applications ea
            on ea.supplier_receiving_evidence_id = sre.supplier_receiving_evidence_id
           and ea.application_status = 'VALID'
          where sre.supplier_receiving_evidence_id in (
            select ma.supplier_receiving_evidence_id from matching_applications ma
          )
            and not exists (
              select 1 from atlas_evidence.evidence_applications successor
              where successor.supersedes_evidence_application_id = ea.evidence_application_id
                and successor.application_status = 'VALID'
            )
          group by sre.supplier_receiving_evidence_id, sre.evidence_quantity
        ) source_totals
        where source_totals.total_applied > source_totals.evidence_quantity
      )
      and not exists (
        select 1 from atlas_dispatch.dispatch_loads dl
        where dl.dispatch_requirement_revision_id = p.dispatch_requirement_revision_id
          and dl.fulfilment_allocation_revision_id = p.fulfilment_allocation_revision_id
          and dl.load_status <> 'VOIDED'
      )
      and not exists (
        select 1
        from atlas_dispatch.dispatch_load_line_applications dlla
        join atlas_dispatch.dispatch_load_lines dll
          on dll.dispatch_load_line_id = dlla.dispatch_load_line_id
        join atlas_procurement.fulfilment_allocation_line_revisions falr
          on falr.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
        where falr.fulfilment_allocation_revision_id = p.fulfilment_allocation_revision_id
          and dll.dispatch_requirement_line_revision_id in (
            select drlr.dispatch_requirement_line_revision_id
            from atlas_planning.dispatch_requirement_line_revisions drlr
            where drlr.dispatch_requirement_revision_id = p.dispatch_requirement_revision_id
          )
          and dlla.application_status = 'VALID'
      )
  );
$$;

create or replace function atlas_api.create_or_assign_dispatch_trip(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'create_or_assign_dispatch_trip';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_plan_id uuid;
  v_plan_status text;
  v_plan_version bigint;
  v_new_plan_version bigint;
  v_plan_service_date date;
  v_trip_reference text;
  v_driver_actor_id uuid;
  v_vehicle_reference text;
  v_planned_departure_at timestamptz;
  v_stop_count integer;
  v_resolved_count integer;
  v_trip_id uuid;
  v_stop_id uuid;
  v_stop_ids jsonb := '[]'::jsonb;
  v_stop_versions jsonb := '[]'::jsonb;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_row record;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05f_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;

  v_plan_id := (v_payload ->> 'dispatch_plan_id')::uuid;
  v_trip_reference := pg_catalog.btrim(v_payload ->> 'trip_reference');
  v_driver_actor_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'driver_actor_id');
  v_vehicle_reference := case
    when pg_catalog.jsonb_typeof(v_payload -> 'vehicle_reference') = 'null' then null
    else pg_catalog.btrim(v_payload ->> 'vehicle_reference')
  end;
  v_planned_departure_at := atlas_core.pa_05b_safe_timestamptz(
    v_payload ->> 'planned_departure_at'
  );
  v_stop_count := pg_catalog.jsonb_array_length(v_payload -> 'stops');

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'DISPATCH', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  if v_driver_actor_id is not null and not exists (
    select 1 from atlas_core.actors a
    where a.actor_id = v_driver_actor_id
      and a.actor_status = 'ACTIVE'
      and a.actor_type in ('HUMAN', 'DELEGATED_DRIVER')
  ) then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'The assigned driver must be an active human or delegated driver.',
      'DISPATCH', v_command_name
    );
  end if;

  -- Resolve and authorize every selected membership before receipt registration.
  select count(*)::integer into v_resolved_count
  from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
  join atlas_dispatch.dispatch_plan_requirements dpr
    on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
   and dpr.dispatch_plan_id = v_plan_id
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
   and loc.customer_id = dr.customer_id;

  if v_resolved_count <> v_stop_count then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'Every submitted stop must resolve to one membership in the selected Dispatch Plan.',
      'DISPATCH', v_command_name
    );
  end if;

  for v_row in
    select distinct dr.customer_id, dr.delivery_location_id
    from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
    join atlas_dispatch.dispatch_plan_requirements dpr
      on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
     and dpr.dispatch_plan_id = v_plan_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    order by dr.customer_id, dr.delivery_location_id
  loop
    v_error := atlas_core.pa_05b_authorize_actor(
      request, v_actor_id, 'dispatch_trip.assign', 'DISPATCH', v_command_name,
      v_row.customer_id, v_row.delivery_location_id, null
    );
    if v_error is not null then return v_error; end if;
  end loop;

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'DISPATCH', 'plan:' || v_plan_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  -- The plan root is the stable assignment parent and is always locked first.
  perform 1 from atlas_dispatch.dispatch_plans dp
    where dp.dispatch_plan_id = v_plan_id for update;

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
  perform 1 from atlas_core.capabilities cap
    where cap.capability_id in (
      select rc.capability_id
      from atlas_core.role_capabilities rc
      join atlas_core.actor_role_memberships arm on arm.role_id = rc.role_id
      where arm.actor_id = v_actor_id
    ) order by cap.capability_id for key share;
  perform 1 from atlas_core.actor_scopes s
    where s.actor_id = v_actor_id
    order by s.actor_scope_id for key share;

  -- Re-enter the global source order for the selected immutable memberships.
  perform 1 from atlas_admin.customers c
    where c.customer_id in (
      select dr.customer_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    ) order by c.customer_id for key share;
  perform 1 from atlas_admin.delivery_locations loc
    where loc.delivery_location_id in (
      select dr.delivery_location_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    ) order by loc.delivery_location_id for key share;
  perform 1 from atlas_admin.suppliers sup
    where sup.supplier_id in (
      select falr.supplier_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
    ) order by sup.supplier_id for key share;
  perform 1 from atlas_admin.ingredients i
    where i.ingredient_id in (
      select drlr.ingredient_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (
      select drlr.unit_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    ) order by u.unit_id for key share;

  perform 1 from atlas_planning.dispatch_requirements dr
    where dr.dispatch_requirement_id in (
      select drr.dispatch_requirement_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    ) order by dr.dispatch_requirement_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_revisions drr
    where drr.dispatch_requirement_revision_id in (
      select dpr.dispatch_requirement_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
    ) order by drr.dispatch_requirement_revision_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_lines drl
    where drl.dispatch_requirement_id in (
      select drr.dispatch_requirement_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    ) order by drl.dispatch_requirement_line_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_line_revisions drlr
    where drlr.dispatch_requirement_revision_id in (
      select dpr.dispatch_requirement_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
    ) order by drlr.dispatch_requirement_line_revision_id for key share;
  for v_row in
    select distinct dr.customer_id, dr.delivery_location_id
    from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
    join atlas_dispatch.dispatch_plan_requirements dpr
      on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
     and dpr.dispatch_plan_id = v_plan_id
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirements dr
      on dr.dispatch_requirement_id = drr.dispatch_requirement_id
    order by dr.customer_id, dr.delivery_location_id
  loop
    v_error := atlas_core.pa_05b_authorize_actor(
      request, v_actor_id, 'dispatch_trip.assign', 'DISPATCH', v_command_name,
      v_row.customer_id, v_row.delivery_location_id, null
    );
    if v_error is not null then
      raise exception using errcode = '40001',
        message = 'dispatch trip authorization scope changed after receipt registration';
    end if;
  end loop;
  perform 1 from atlas_planning.wholesale_orders wo
    where wo.wholesale_order_id in (
      select cnb.wholesale_order_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb
        on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      join atlas_planning.confirmed_need_batches cnb
        on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
    ) order by wo.wholesale_order_id for key share;
  perform 1 from atlas_planning.wholesale_order_lines wol
    where wol.wholesale_order_id in (
      select wo.wholesale_order_id
      from atlas_planning.wholesale_orders wo
      join atlas_planning.confirmed_need_batches cnb
        on cnb.wholesale_order_id = wo.wholesale_order_id
      join atlas_planning.purchase_handoff_batches phb
        on phb.confirmed_need_batch_id = cnb.confirmed_need_batch_id
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_batch_id = phb.purchase_handoff_batch_id
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.purchase_handoff_revision_id = phr.purchase_handoff_revision_id
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
      where dpr.dispatch_plan_requirement_id in (
        select (item ->> 'dispatch_plan_requirement_id')::uuid
        from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      )
    ) order by wol.wholesale_order_line_id for key share;
  perform 1 from atlas_planning.wholesale_order_line_revisions wolr
    where wolr.wholesale_order_line_revision_id in (
      select pdr.wholesale_order_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.purchase_demand_references pdr
        on pdr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    ) order by wolr.wholesale_order_line_revision_id for key share;
  perform 1 from atlas_planning.confirmed_need_batches cnb
    where cnb.confirmed_need_batch_id in (
      select phb.confirmed_need_batch_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb
        on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
    ) order by cnb.confirmed_need_batch_id for key share;
  perform 1 from atlas_planning.confirmed_need_lines cnl
    where cnl.confirmed_need_line_id in (
      select phl.confirmed_need_line_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirement_lines drl
        on drl.dispatch_requirement_id = drr.dispatch_requirement_id
      join atlas_planning.purchase_handoff_lines phl
        on phl.purchase_handoff_line_id = drl.purchase_handoff_line_id
    ) order by cnl.confirmed_need_line_id for key share;
  perform 1 from atlas_planning.confirmed_need_line_revisions cnlr
    where cnlr.confirmed_need_line_revision_id in (
      select phlr.confirmed_need_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.purchase_handoff_line_revisions phlr
        on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    ) order by cnlr.confirmed_need_line_revision_id for key share;
  perform 1 from atlas_planning.confirmed_need_snapshot_lines cnsl
    where cnsl.confirmed_need_snapshot_line_id in (
      select pdr.confirmed_need_snapshot_line_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.purchase_demand_references pdr
        on pdr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
    ) order by cnsl.confirmed_need_snapshot_line_id for key share;
  perform 1 from atlas_planning.confirmed_need_approval_snapshots cns
    where cns.confirmed_need_approval_snapshot_id in (
      select cnsl.confirmed_need_approval_snapshot_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.purchase_demand_references pdr
        on pdr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
      join atlas_planning.confirmed_need_snapshot_lines cnsl
        on cnsl.confirmed_need_snapshot_line_id = pdr.confirmed_need_snapshot_line_id
    ) order by cns.confirmed_need_approval_snapshot_id for key share;
  perform 1 from atlas_planning.purchase_handoff_batches phb
    where phb.purchase_handoff_batch_id in (
      select phr.purchase_handoff_batch_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
    ) order by phb.purchase_handoff_batch_id for key share;
  perform 1 from atlas_planning.purchase_handoff_lines phl
    where phl.purchase_handoff_line_id in (
      select drl.purchase_handoff_line_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirement_lines drl
        on drl.dispatch_requirement_id = drr.dispatch_requirement_id
    ) order by phl.purchase_handoff_line_id for key share;
  perform 1 from atlas_planning.purchase_handoff_revisions phr
    where phr.purchase_handoff_revision_id in (
      select drr.purchase_handoff_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    ) order by phr.purchase_handoff_revision_id for key share;
  perform 1 from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_revision_id in (
      select drr.purchase_handoff_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    ) order by phlr.purchase_handoff_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_demand_references pdr
    where pdr.purchase_handoff_line_revision_id in (
      select drlr.purchase_handoff_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
    ) order by pdr.purchase_demand_reference_id for key share;

  perform 1 from atlas_procurement.fulfilment_allocations fa
    where fa.fulfilment_allocation_id in (
      select far.fulfilment_allocation_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_procurement.fulfilment_allocation_revisions far
        on far.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
    ) order by fa.fulfilment_allocation_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_revisions far
    where far.fulfilment_allocation_revision_id in (
      select dpr.fulfilment_allocation_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
    ) order by far.fulfilment_allocation_revision_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_lines fal
    where fal.fulfilment_allocation_id in (
      select far.fulfilment_allocation_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_procurement.fulfilment_allocation_revisions far
        on far.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
    ) order by fal.fulfilment_allocation_line_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
    where falr.fulfilment_allocation_revision_id in (
      select dpr.fulfilment_allocation_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
    ) order by falr.fulfilment_allocation_line_revision_id for key share;
  perform 1 from atlas_procurement.purchase_orders po
    where po.purchase_order_id in (
      select pol.purchase_order_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
      join atlas_procurement.purchase_order_lines pol
        on pol.fulfilment_allocation_line_id = falr.fulfilment_allocation_line_id
    ) order by po.purchase_order_id for key share;
  perform 1 from atlas_procurement.purchase_order_revisions por
    where por.purchase_order_id in (
      select pol.purchase_order_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
      join atlas_procurement.purchase_order_lines pol
        on pol.fulfilment_allocation_line_id = falr.fulfilment_allocation_line_id
    ) order by por.purchase_order_revision_id for key share;
  perform 1 from atlas_procurement.purchase_order_lines pol
    where pol.fulfilment_allocation_line_id in (
      select falr.fulfilment_allocation_line_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
    ) order by pol.purchase_order_line_id for key share;
  perform 1 from atlas_procurement.purchase_order_line_revisions polr
    where polr.fulfilment_allocation_line_revision_id in (
      select falr.fulfilment_allocation_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
    ) order by polr.purchase_order_line_revision_id for key share;
  perform 1 from atlas_evidence.supplier_receiving_evidence sre
    where sre.supplier_receiving_evidence_id in (
      select ea.supplier_receiving_evidence_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
      join atlas_evidence.evidence_applications ea
        on ea.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
    ) order by sre.supplier_receiving_evidence_id for key share;
  perform 1 from atlas_evidence.evidence_applications ea
    where ea.fulfilment_allocation_line_revision_id in (
      select falr.fulfilment_allocation_line_revision_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
    ) order by ea.evidence_application_id for key share;

  -- Finish with membership and current plan assignment state.
  perform 1 from atlas_dispatch.dispatch_plan_requirements dpr
    where dpr.dispatch_plan_requirement_id in (
      select (item ->> 'dispatch_plan_requirement_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
    ) order by dpr.dispatch_plan_requirement_id for key share;
  perform 1 from atlas_dispatch.dispatch_trips dt
    where dt.dispatch_plan_id = v_plan_id
    order by dt.dispatch_trip_id for key share;
  perform 1 from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id in (
      select dt.dispatch_trip_id from atlas_dispatch.dispatch_trips dt
      where dt.dispatch_plan_id = v_plan_id
    ) order by ds.dispatch_stop_id for key share;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('PA-05F:TRIP:' || v_trip_reference, 0)
  );

  select dp.plan_status, dp.version, dp.service_date
    into v_plan_status, v_plan_version, v_plan_service_date
  from atlas_dispatch.dispatch_plans dp
  where dp.dispatch_plan_id = v_plan_id;

  if v_plan_version <> (request ->> 'expected_version')::bigint then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION',
      'The Dispatch Plan changed. Refresh and review before assigning a trip.',
      'DISPATCH', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_plan_id), v_plan_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_plan_status <> 'PLANNED'
     or (v_driver_actor_id is not null and not exists (
       select 1 from atlas_core.actors a
       where a.actor_id = v_driver_actor_id
         and a.actor_status = 'ACTIVE'
         and a.actor_type in ('HUMAN', 'DELEGATED_DRIVER')
     ))
     or exists (
       select 1
       from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
       join atlas_dispatch.dispatch_plan_requirements dpr
         on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
        and dpr.dispatch_plan_id = v_plan_id
       join atlas_planning.dispatch_requirement_revisions drr
         on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
       join atlas_planning.dispatch_requirements dr
         on dr.dispatch_requirement_id = drr.dispatch_requirement_id
       where dr.service_date <> v_plan_service_date
          or not atlas_core.pa_05f_dispatch_pair_is_ready(
            dpr.dispatch_requirement_revision_id,
            dpr.fulfilment_allocation_revision_id
          )
     )
     or exists (
       select 1
       from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
       join atlas_dispatch.dispatch_plan_requirements selected
         on selected.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
        and selected.dispatch_plan_id = v_plan_id
       join atlas_dispatch.dispatch_stops ds
         on ds.dispatch_requirement_revision_id = selected.dispatch_requirement_revision_id
       join atlas_dispatch.dispatch_trips dt
         on dt.dispatch_trip_id = ds.dispatch_trip_id
        and dt.dispatch_plan_id = v_plan_id
       where dt.trip_status not in ('CANCELLED', 'VOIDED')
     )
     or exists (
       select 1 from atlas_dispatch.dispatch_trips dt
       where dt.trip_reference = v_trip_reference
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'Trip assignment requires an unchanged planned root, fully evidenced unassigned memberships, and an unused reference.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  v_new_plan_version := v_plan_version + 1;
  begin
    update atlas_dispatch.dispatch_plans dp
    set version = v_new_plan_version,
        updated_at = pg_catalog.transaction_timestamp()
    where dp.dispatch_plan_id = v_plan_id
      and dp.plan_status = 'PLANNED'
      and dp.version = v_plan_version;

    insert into atlas_dispatch.dispatch_trips (
      dispatch_plan_id, trip_reference, trip_status, driver_actor_id,
      vehicle_reference, planned_departure_at, version
    ) values (
      v_plan_id, v_trip_reference, 'ASSIGNED', v_driver_actor_id,
      v_vehicle_reference, v_planned_departure_at, 1
    ) returning dispatch_trip_id into v_trip_id;

    for v_row in
      select (item ->> 'stop_sequence')::integer as stop_sequence,
             dpr.dispatch_requirement_revision_id,
             dr.customer_id, dr.delivery_location_id
      from pg_catalog.jsonb_array_elements(v_payload -> 'stops') item
      join atlas_dispatch.dispatch_plan_requirements dpr
        on dpr.dispatch_plan_requirement_id = (item ->> 'dispatch_plan_requirement_id')::uuid
       and dpr.dispatch_plan_id = v_plan_id
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
      order by (item ->> 'stop_sequence')::integer
    loop
      insert into atlas_dispatch.dispatch_stops (
        dispatch_trip_id, stop_sequence, dispatch_requirement_revision_id,
        customer_id, delivery_location_id, planned_window_start,
        planned_window_end, stop_status, version
      ) values (
        v_trip_id, v_row.stop_sequence, v_row.dispatch_requirement_revision_id,
        v_row.customer_id, v_row.delivery_location_id, null, null, 'PENDING', 1
      ) returning dispatch_stop_id into v_stop_id;
      v_stop_ids := v_stop_ids || pg_catalog.jsonb_build_array(v_stop_id);
      v_stop_versions := v_stop_versions || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('dispatch_stop_id', v_stop_id, 'version', 1)
      );
    end loop;

    insert into atlas_audit.domain_events (
      event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
      command_receipt_id, command_id, correlation_id, actor_id, occurred_at,
      payload_summary
    ) values (
      'DispatchTripAssigned', 'DISPATCH', 'DispatchTrip', v_trip_id, 1,
      v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
      pg_catalog.transaction_timestamp(),
      pg_catalog.jsonb_build_object(
        'dispatch_plan_id', v_plan_id, 'dispatch_plan_version', v_new_plan_version,
        'trip_reference', v_trip_reference, 'stop_count', v_stop_count
      )
    ) returning domain_event_id into v_domain_event_id;

    insert into atlas_audit.audit_events (
      event_type, source_domain, aggregate_type, aggregate_id,
      aggregate_version_after, command_receipt_id, command_id, correlation_id,
      actor_id, reason_code, reason_note, after_summary, source_interface,
      occurred_at
    ) values (
      'DispatchTripAssigned', 'DISPATCH', 'DispatchTrip', v_trip_id, 1,
      v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
      request ->> 'reason_code', request ->> 'reason_note',
      pg_catalog.jsonb_build_object(
        'trip_status', 'ASSIGNED', 'trip_reference', v_trip_reference,
        'dispatch_plan_id', v_plan_id, 'dispatch_plan_version', v_new_plan_version,
        'stop_count', v_stop_count
      ),
      'atlas_api', pg_catalog.transaction_timestamp()
    ) returning audit_event_id into v_audit_event_id;
  exception
    when unique_violation then
      v_error := atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'The trip reference, stop sequence, or selected assignment is already in use.',
        'DISPATCH', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end;

  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'dispatch_plan_id', v_plan_id, 'dispatch_trip_id', v_trip_id,
      'dispatch_stop_ids', v_stop_ids
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'dispatch_plan_version', v_new_plan_version,
      'dispatch_trip_version', 1,
      'dispatch_stop_versions', v_stop_versions
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Dispatch trip assigned from fully evidenced plan memberships.',
    'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'DISPATCH', v_command_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'The Dispatch trip could not be assigned safely.',
      'DISPATCH', v_command_name
    );
end;
$$;

-- Extend only the already hardened Dispatch runtime. Existing UPDATE grants on
-- upstream relations remain lock-only because no UPDATE policy is added there.
grant insert on
  atlas_dispatch.dispatch_plans,
  atlas_dispatch.dispatch_plan_requirements,
  atlas_dispatch.dispatch_trips,
  atlas_dispatch.dispatch_stops
to atlas_dispatch_command_runtime;
grant update on atlas_dispatch.dispatch_plans
to atlas_dispatch_command_runtime;
grant update on
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes
to atlas_dispatch_command_runtime;

create policy pa_05f_dispatch_insert on atlas_dispatch.dispatch_plans
  for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05f_dispatch_update on atlas_dispatch.dispatch_plans
  for update to atlas_dispatch_command_runtime using (true) with check (true);
create policy pa_05f_dispatch_insert on atlas_dispatch.dispatch_plan_requirements
  for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05f_dispatch_insert on atlas_dispatch.dispatch_trips
  for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05f_dispatch_insert on atlas_dispatch.dispatch_stops
  for insert to atlas_dispatch_command_runtime with check (true);

alter function atlas_core.pa_05f_validate_command_request(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.pa_05f_dispatch_pair_is_ready(uuid, uuid)
  owner to atlas_owner;
revoke execute on function
  atlas_core.pa_05f_validate_command_request(jsonb, text),
  atlas_core.pa_05f_dispatch_pair_is_ready(uuid, uuid)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.pa_05f_validate_command_request(jsonb, text),
  atlas_core.pa_05f_dispatch_pair_is_ready(uuid, uuid)
to atlas_dispatch_command_runtime;

comment on function atlas_api.create_dispatch_plan(jsonb) is
  'PA-05F atomic Dispatch Plan creation from same-date, fully evidenced exact requirement/allocation pairs.';
comment on function atlas_api.create_or_assign_dispatch_trip(jsonb) is
  'PA-05F atomic assigned-trip and derived-stop creation from fully evidenced unassigned plan memberships.';
comment on role atlas_dispatch_command_runtime is
  'NOLOGIN NOINHERIT SECURITY DEFINER owner for the three PA-05B-H2 execution commands and two PA-05F setup commands.';

-- Ownership transfer temporarily requires schema CREATE and role membership.
grant atlas_dispatch_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_dispatch_command_runtime;
alter function atlas_api.create_dispatch_plan(jsonb)
  owner to atlas_dispatch_command_runtime;
alter function atlas_api.create_or_assign_dispatch_trip(jsonb)
  owner to atlas_dispatch_command_runtime;
revoke create on schema atlas_api from atlas_dispatch_command_runtime;

-- Revoke first, then expose only the two reviewed PA-05F entry points.
grant usage on schema atlas_api to authenticated;
set role atlas_dispatch_command_runtime;
revoke execute on function
  atlas_api.create_dispatch_plan(jsonb),
  atlas_api.create_or_assign_dispatch_trip(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_api.create_dispatch_plan(jsonb),
  atlas_api.create_or_assign_dispatch_trip(jsonb)
to authenticated;
reset role;
revoke atlas_dispatch_command_runtime from postgres;
