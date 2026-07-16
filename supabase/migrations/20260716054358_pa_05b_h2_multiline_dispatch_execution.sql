-- PA-05B-H2: atomic multi-line Dispatch execution correction.
--
-- This migration replaces exactly three existing atlas_api function bodies,
-- adds one private request validator, and extends only the read/row-lock
-- surface needed to prove complete Planning, Procurement, PO, and Evidence
-- lineage. It adds no public function, table, view, trigger, sequence, role,
-- queue, job, or cross-domain mutation policy.

create or replace function atlas_core.pa_05b_h2_validate_command_request(
  request jsonb,
  command_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_payload jsonb;
  v_errors jsonb := '[]'::jsonb;
  v_requested_at timestamptz;
  v_line jsonb;
  v_application jsonb;
  v_line_count integer;
  v_application_count integer;
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

  if not (request ?& array[
       'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
       'expected_version', 'requested_by_auth_subject', 'requested_at',
       'reason_code', 'reason_note', 'payload'
     ])
     or request - array[
       'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
       'expected_version', 'requested_by_auth_subject', 'requested_at',
       'reason_code', 'reason_note', 'payload'
     ] <> '{}'::jsonb then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'request', 'message', 'Use the exact PA-05B-H2 command envelope.')
    );
  end if;

  if request ->> 'contract_version' is distinct from 'PA-05B-H2.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use PA-05B-H2.v1.')
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
      pg_catalog.jsonb_build_object('field', 'idempotency_key', 'message', 'A non-empty key of at most 200 characters is required.')
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

  v_payload := request -> 'payload';
  if v_payload is null or pg_catalog.jsonb_typeof(v_payload) <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'A JSON object is required.')
    );
  elsif command_name = 'confirm_dispatch_load' then
    if not (v_payload ?& array[
         'dispatch_trip_id', 'dispatch_stop_id',
         'dispatch_requirement_revision_id',
         'fulfilment_allocation_revision_id', 'loaded_at', 'lines'
       ])
       or v_payload - array[
         'dispatch_trip_id', 'dispatch_stop_id',
         'dispatch_requirement_revision_id',
         'fulfilment_allocation_revision_id', 'loaded_at', 'lines'
       ] <> '{}'::jsonb
       or atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_trip_id') is null
       or atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_stop_id') is null
       or atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_requirement_revision_id') is null
       or atlas_core.pa_05b_safe_uuid(v_payload ->> 'fulfilment_allocation_revision_id') is null
       or atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'loaded_at') is null then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Use the exact multi-line load payload.')
      );
    end if;

    if pg_catalog.jsonb_typeof(v_payload -> 'lines') <> 'array' then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'An array of 1 to 100 lines is required.')
      );
    else
      v_line_count := pg_catalog.jsonb_array_length(v_payload -> 'lines');
      if v_line_count < 1 or v_line_count > 100 then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Provide 1 to 100 lines.')
        );
      end if;

      for v_line in select value from pg_catalog.jsonb_array_elements(v_payload -> 'lines') loop
        if pg_catalog.jsonb_typeof(v_line) <> 'object'
           or not (v_line ?& array[
             'dispatch_requirement_line_revision_id',
             'fulfilment_allocation_line_revision_id', 'loaded_quantity',
             'unit_id', 'evidence_applications'
           ])
           or v_line - array[
             'dispatch_requirement_line_revision_id',
             'fulfilment_allocation_line_revision_id', 'loaded_quantity',
             'unit_id', 'evidence_applications'
           ] <> '{}'::jsonb
           or atlas_core.pa_05b_safe_uuid(v_line ->> 'dispatch_requirement_line_revision_id') is null
           or atlas_core.pa_05b_safe_uuid(v_line ->> 'fulfilment_allocation_line_revision_id') is null
           or atlas_core.pa_05b_safe_numeric(v_line ->> 'loaded_quantity') is null
           or atlas_core.pa_05b_safe_numeric(v_line ->> 'loaded_quantity') <= 0
           or atlas_core.pa_05b_safe_uuid(v_line ->> 'unit_id') is null
           or pg_catalog.jsonb_typeof(v_line -> 'evidence_applications') <> 'array' then
          v_errors := v_errors || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Every load line must use the exact valid shape.')
          );
          continue;
        end if;

        v_application_count := pg_catalog.jsonb_array_length(v_line -> 'evidence_applications');
        if v_application_count < 1 or v_application_count > 100 then
          v_errors := v_errors || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('field', 'payload.lines.evidence_applications', 'message', 'Provide 1 to 100 applications per line.')
          );
        end if;

        for v_application in
          select value from pg_catalog.jsonb_array_elements(v_line -> 'evidence_applications')
        loop
          if pg_catalog.jsonb_typeof(v_application) <> 'object'
             or not (v_application ?& array[
               'evidence_application_id', 'applied_to_load_quantity', 'unit_id'
             ])
             or v_application - array[
               'evidence_application_id', 'applied_to_load_quantity', 'unit_id'
             ] <> '{}'::jsonb
             or atlas_core.pa_05b_safe_uuid(v_application ->> 'evidence_application_id') is null
             or atlas_core.pa_05b_safe_numeric(v_application ->> 'applied_to_load_quantity') is null
             or atlas_core.pa_05b_safe_numeric(v_application ->> 'applied_to_load_quantity') <= 0
             or atlas_core.pa_05b_safe_uuid(v_application ->> 'unit_id') is null then
            v_errors := v_errors || pg_catalog.jsonb_build_array(
              pg_catalog.jsonb_build_object('field', 'payload.lines.evidence_applications', 'message', 'Every evidence application must use the exact valid shape.')
            );
          end if;
        end loop;
      end loop;

      if exists (
        select 1
        from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
        group by atlas_core.pa_05b_safe_uuid(line_value ->> 'dispatch_requirement_line_revision_id')
        having count(*) > 1
      ) or exists (
        select 1
        from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
        group by atlas_core.pa_05b_safe_uuid(line_value ->> 'fulfilment_allocation_line_revision_id')
        having count(*) > 1
      ) or exists (
        select 1
        from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
        cross join lateral pg_catalog.jsonb_array_elements(
          case when pg_catalog.jsonb_typeof(line_value -> 'evidence_applications') = 'array'
            then line_value -> 'evidence_applications' else '[]'::jsonb end
        ) application_value
        group by atlas_core.pa_05b_safe_uuid(application_value ->> 'evidence_application_id')
        having count(*) > 1
      ) then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Line and evidence-application identities must be unique.')
        );
      end if;
    end if;
  elsif command_name = 'record_dispatch_departure' then
    if not (v_payload ?& array['dispatch_trip_id', 'departed_at'])
       or v_payload - array['dispatch_trip_id', 'departed_at'] <> '{}'::jsonb
       or atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_trip_id') is null
       or atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'departed_at') is null then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Provide only dispatch_trip_id and departed_at.')
      );
    end if;
  elsif command_name = 'confirm_successful_delivery' then
    if not (v_payload ?& array[
         'dispatch_trip_id', 'dispatch_stop_id', 'confirmed_at',
         'received_by_reference', 'notes', 'lines'
       ])
       or v_payload - array[
         'dispatch_trip_id', 'dispatch_stop_id', 'confirmed_at',
         'received_by_reference', 'notes', 'lines'
       ] <> '{}'::jsonb
       or atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_trip_id') is null
       or atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_stop_id') is null
       or atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'confirmed_at') is null
       or (v_payload -> 'received_by_reference' <> 'null'::jsonb
           and pg_catalog.jsonb_typeof(v_payload -> 'received_by_reference') <> 'string')
       or (v_payload -> 'notes' <> 'null'::jsonb
           and pg_catalog.jsonb_typeof(v_payload -> 'notes') <> 'string') then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Use the exact multi-line successful-delivery payload.')
      );
    end if;

    if pg_catalog.jsonb_typeof(v_payload -> 'lines') <> 'array' then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'An array of 1 to 100 lines is required.')
      );
    else
      v_line_count := pg_catalog.jsonb_array_length(v_payload -> 'lines');
      if v_line_count < 1 or v_line_count > 100 then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Provide 1 to 100 lines.')
        );
      end if;

      for v_line in select value from pg_catalog.jsonb_array_elements(v_payload -> 'lines') loop
        if pg_catalog.jsonb_typeof(v_line) <> 'object'
           or not (v_line ?& array[
             'dispatch_load_line_id', 'delivered_quantity', 'returned_quantity',
             'exception_quantity', 'unit_id'
           ])
           or v_line - array[
             'dispatch_load_line_id', 'delivered_quantity', 'returned_quantity',
             'exception_quantity', 'unit_id'
           ] <> '{}'::jsonb
           or atlas_core.pa_05b_safe_uuid(v_line ->> 'dispatch_load_line_id') is null
           or atlas_core.pa_05b_safe_numeric(v_line ->> 'delivered_quantity') is null
           or atlas_core.pa_05b_safe_numeric(v_line ->> 'delivered_quantity') <= 0
           or atlas_core.pa_05b_safe_numeric(v_line ->> 'returned_quantity') is null
           or atlas_core.pa_05b_safe_numeric(v_line ->> 'exception_quantity') is null
           or atlas_core.pa_05b_safe_uuid(v_line ->> 'unit_id') is null then
          v_errors := v_errors || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Every delivery line must use the exact valid shape.')
          );
        end if;
      end loop;

      if exists (
        select 1
        from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
        group by atlas_core.pa_05b_safe_uuid(line_value ->> 'dispatch_load_line_id')
        having count(*) > 1
      ) then
        v_errors := v_errors || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Load-line identities must be unique.')
        );
      end if;
    end if;
  else
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'command_name', 'message', 'Unsupported PA-05B-H2 command.')
    );
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The PA-05B-H2 command request is invalid.',
      'DISPATCH', command_name, false, v_errors
    );
  end if;
  return null;
end;
$$;

revoke all on function atlas_core.pa_05b_h2_validate_command_request(jsonb, text) from public;
grant execute on function atlas_core.pa_05b_h2_validate_command_request(jsonb, text)
  to atlas_dispatch_command_runtime;

-- The Dispatch runtime receives only read and row-lock privileges for the
-- additional lineage relations. Forced RLS has SELECT-only policies below,
-- so these UPDATE grants cannot mutate Planning, Procurement, or Admin rows.
grant select, update on
  atlas_admin.customers,
  atlas_admin.suppliers,
  atlas_planning.wholesale_orders,
  atlas_planning.wholesale_order_lines,
  atlas_planning.wholesale_order_line_revisions,
  atlas_planning.confirmed_need_batches,
  atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_approval_snapshots,
  atlas_planning.confirmed_need_snapshot_lines,
  atlas_planning.purchase_handoff_batches,
  atlas_planning.purchase_handoff_revisions,
  atlas_planning.purchase_handoff_lines,
  atlas_planning.purchase_handoff_line_revisions,
  atlas_planning.purchase_demand_references,
  atlas_planning.dispatch_requirement_lines,
  atlas_procurement.fulfilment_allocation_lines,
  atlas_procurement.purchase_orders,
  atlas_procurement.purchase_order_revisions,
  atlas_procurement.purchase_order_lines,
  atlas_procurement.purchase_order_line_revisions,
  atlas_dispatch.dispatch_plan_requirements
to atlas_dispatch_command_runtime;

grant update on atlas_core.actors to atlas_dispatch_command_runtime;

create policy pa_05b_h2_dispatch_select on atlas_admin.customers
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_admin.suppliers
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.wholesale_orders
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.wholesale_order_lines
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.wholesale_order_line_revisions
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.confirmed_need_batches
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.confirmed_need_lines
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.confirmed_need_line_revisions
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.confirmed_need_approval_snapshots
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.confirmed_need_snapshot_lines
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.purchase_handoff_batches
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.purchase_handoff_revisions
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.purchase_handoff_lines
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.purchase_handoff_line_revisions
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.purchase_demand_references
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_planning.dispatch_requirement_lines
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_procurement.fulfilment_allocation_lines
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_procurement.purchase_orders
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_procurement.purchase_order_revisions
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_procurement.purchase_order_lines
  for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h2_dispatch_select on atlas_procurement.purchase_order_line_revisions
  for select to atlas_dispatch_command_runtime using (true);

grant atlas_dispatch_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_dispatch_command_runtime;
set role atlas_dispatch_command_runtime;

create or replace function atlas_api.confirm_dispatch_load(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'confirm_dispatch_load';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_trip_id uuid;
  v_stop_id uuid;
  v_requirement_revision_id uuid;
  v_allocation_revision_id uuid;
  v_loaded_at timestamptz;
  v_plan_id uuid;
  v_trip_status text;
  v_trip_version bigint;
  v_driver_actor_id uuid;
  v_vehicle_reference text;
  v_stop_status text;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_requirement_id uuid;
  v_allocation_id uuid;
  v_driver_status text;
  v_requirement_root_count integer;
  v_requirement_revision_count integer;
  v_allocation_root_count integer;
  v_allocation_revision_count integer;
  v_submitted_count integer;
  v_valid_count integer;
  v_application_count integer;
  v_valid_application_count integer;
  v_load_id uuid;
  v_load_line_id uuid;
  v_load_line_application_id uuid;
  v_load_line_ids jsonb := '[]'::jsonb;
  v_load_line_application_ids jsonb := '[]'::jsonb;
  v_new_trip_version bigint;
  v_new_stop_version bigint;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_line record;
  v_application record;
  v_ingredient_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05b_h2_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;

  v_trip_id := (v_payload ->> 'dispatch_trip_id')::uuid;
  v_stop_id := (v_payload ->> 'dispatch_stop_id')::uuid;
  v_requirement_revision_id := (v_payload ->> 'dispatch_requirement_revision_id')::uuid;
  v_allocation_revision_id := (v_payload ->> 'fulfilment_allocation_revision_id')::uuid;
  v_loaded_at := (v_payload ->> 'loaded_at')::timestamptz;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'DISPATCH', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := (v_actor_context ->> 'actor_id')::uuid;

  select dt.dispatch_plan_id, dt.trip_status, dt.version,
         dt.driver_actor_id, dt.vehicle_reference,
         ds.stop_status, ds.customer_id, ds.delivery_location_id,
         drr.dispatch_requirement_id, far.fulfilment_allocation_id
    into v_plan_id, v_trip_status, v_trip_version,
         v_driver_actor_id, v_vehicle_reference,
         v_stop_status, v_customer_id, v_delivery_location_id,
         v_requirement_id, v_allocation_id
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_stops ds
    on ds.dispatch_trip_id = dt.dispatch_trip_id
  join atlas_dispatch.dispatch_plan_requirements dpr
    on dpr.dispatch_plan_id = dt.dispatch_plan_id
   and dpr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
  join atlas_procurement.fulfilment_allocation_revisions far
    on far.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
  where dt.dispatch_trip_id = v_trip_id
    and ds.dispatch_stop_id = v_stop_id
    and ds.dispatch_requirement_revision_id = v_requirement_revision_id
    and dpr.dispatch_requirement_revision_id = v_requirement_revision_id
    and dpr.fulfilment_allocation_revision_id = v_allocation_revision_id;

  if not found then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'The trip, stop, requirement, and allocation membership could not be validated.',
      'DISPATCH', v_command_name
    );
  end if;

  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'dispatch_load.confirm', 'DISPATCH', v_command_name,
    v_customer_id, v_delivery_location_id, v_trip_id
  );
  if v_authorization_error is not null then return v_authorization_error; end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'DISPATCH',
    'trip:' || v_trip_id::text || ':allocation-revision:' || v_allocation_revision_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := (v_begin ->> 'receipt_id')::uuid;

  -- Admin/Core references.
  perform 1 from atlas_core.actors a
    where a.actor_id = v_driver_actor_id for key share;
  perform 1 from atlas_admin.customers c
    where c.customer_id = v_customer_id for key share;
  perform 1 from atlas_admin.delivery_locations dl
    where dl.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_admin.suppliers s
    where s.supplier_id in (
      select falr.supplier_id
      from atlas_procurement.fulfilment_allocation_line_revisions falr
      where falr.fulfilment_allocation_revision_id = v_allocation_revision_id
    ) order by s.supplier_id for key share;
  perform 1 from atlas_admin.ingredients i
    where i.ingredient_id in (
      select drlr.ingredient_id
      from atlas_planning.dispatch_requirement_line_revisions drlr
      where drlr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (
      select drlr.unit_id
      from atlas_planning.dispatch_requirement_line_revisions drlr
      where drlr.dispatch_requirement_revision_id = v_requirement_revision_id
      union
      select (line_value ->> 'unit_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
    ) order by u.unit_id for key share;

  -- Complete Planning lineage.
  perform 1 from atlas_planning.wholesale_orders wo
    where wo.wholesale_order_id in (
      select cnb.wholesale_order_id
      from atlas_planning.dispatch_requirement_revisions drr
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb
        on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      join atlas_planning.confirmed_need_batches cnb
        on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) for key share;
  perform 1 from atlas_planning.wholesale_order_lines wol
    where wol.wholesale_order_id in (
      select cnb.wholesale_order_id
      from atlas_planning.dispatch_requirement_revisions drr
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb
        on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      join atlas_planning.confirmed_need_batches cnb
        on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) order by wol.wholesale_order_line_id for key share;
  perform 1 from atlas_planning.wholesale_order_line_revisions wolr
    where wolr.wholesale_order_line_id in (
      select wol.wholesale_order_line_id
      from atlas_planning.wholesale_order_lines wol
      join atlas_planning.wholesale_orders wo on wo.wholesale_order_id = wol.wholesale_order_id
      join atlas_planning.confirmed_need_batches cnb on cnb.wholesale_order_id = wo.wholesale_order_id
      join atlas_planning.purchase_handoff_batches phb on phb.confirmed_need_batch_id = cnb.confirmed_need_batch_id
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_batch_id = phb.purchase_handoff_batch_id
      join atlas_planning.dispatch_requirement_revisions drr on drr.purchase_handoff_revision_id = phr.purchase_handoff_revision_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) order by wolr.wholesale_order_line_revision_id for key share;
  perform 1 from atlas_planning.confirmed_need_batches cnb
    where cnb.confirmed_need_batch_id in (
      select phb.confirmed_need_batch_id
      from atlas_planning.dispatch_requirement_revisions drr
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) for key share;
  perform 1 from atlas_planning.confirmed_need_lines cnl
    where cnl.confirmed_need_batch_id in (
      select phb.confirmed_need_batch_id
      from atlas_planning.dispatch_requirement_revisions drr
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) order by cnl.confirmed_need_line_id for key share;
  perform 1 from atlas_planning.confirmed_need_line_revisions cnlr
    where cnlr.confirmed_need_line_id in (
      select cnl.confirmed_need_line_id
      from atlas_planning.confirmed_need_lines cnl
      join atlas_planning.confirmed_need_batches cnb on cnb.confirmed_need_batch_id = cnl.confirmed_need_batch_id
      join atlas_planning.purchase_handoff_batches phb on phb.confirmed_need_batch_id = cnb.confirmed_need_batch_id
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_batch_id = phb.purchase_handoff_batch_id
      join atlas_planning.dispatch_requirement_revisions drr on drr.purchase_handoff_revision_id = phr.purchase_handoff_revision_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) order by cnlr.confirmed_need_line_revision_id for key share;
  perform 1 from atlas_planning.confirmed_need_approval_snapshots cns
    where cns.confirmed_need_batch_id in (
      select phb.confirmed_need_batch_id
      from atlas_planning.dispatch_requirement_revisions drr
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) order by cns.confirmed_need_approval_snapshot_id for key share;
  perform 1 from atlas_planning.confirmed_need_snapshot_lines cnsl
    where cnsl.confirmed_need_approval_snapshot_id in (
      select cns.confirmed_need_approval_snapshot_id
      from atlas_planning.confirmed_need_approval_snapshots cns
      join atlas_planning.purchase_handoff_batches phb on phb.confirmed_need_batch_id = cns.confirmed_need_batch_id
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_batch_id = phb.purchase_handoff_batch_id
      join atlas_planning.dispatch_requirement_revisions drr on drr.purchase_handoff_revision_id = phr.purchase_handoff_revision_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) order by cnsl.confirmed_need_snapshot_line_id for key share;
  perform 1 from atlas_planning.purchase_handoff_batches phb
    where phb.purchase_handoff_batch_id in (
      select phr.purchase_handoff_batch_id from atlas_planning.purchase_handoff_revisions phr
      join atlas_planning.dispatch_requirement_revisions drr on drr.purchase_handoff_revision_id = phr.purchase_handoff_revision_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) for key share;
  perform 1 from atlas_planning.purchase_handoff_revisions phr
    where phr.purchase_handoff_revision_id in (
      select drr.purchase_handoff_revision_id from atlas_planning.dispatch_requirement_revisions drr
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) for key share;
  perform 1 from atlas_planning.purchase_handoff_lines phl
    where phl.purchase_handoff_line_id in (
      select drl.purchase_handoff_line_id from atlas_planning.dispatch_requirement_lines drl
      where drl.dispatch_requirement_id = v_requirement_id
    ) order by phl.purchase_handoff_line_id for key share;
  perform 1 from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_revision_id in (
      select drr.purchase_handoff_revision_id from atlas_planning.dispatch_requirement_revisions drr
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) order by phlr.purchase_handoff_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_demand_references pdr
    where pdr.purchase_handoff_line_revision_id in (
      select phlr.purchase_handoff_line_revision_id from atlas_planning.purchase_handoff_line_revisions phlr
      join atlas_planning.dispatch_requirement_revisions drr on drr.purchase_handoff_revision_id = phlr.purchase_handoff_revision_id
      where drr.dispatch_requirement_revision_id = v_requirement_revision_id
    ) order by pdr.purchase_demand_reference_id for key share;
  perform 1 from atlas_planning.dispatch_requirements dr
    where dr.dispatch_requirement_id = v_requirement_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_revisions drr
    where drr.dispatch_requirement_revision_id = v_requirement_revision_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_lines drl
    where drl.dispatch_requirement_id = v_requirement_id
    order by drl.dispatch_requirement_line_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_line_revisions drlr
    where drlr.dispatch_requirement_revision_id = v_requirement_revision_id
    order by drlr.dispatch_requirement_line_revision_id for key share;

  -- Procurement and released supplier-PO lineage.
  perform 1 from atlas_procurement.fulfilment_allocations fa
    where fa.fulfilment_allocation_id = v_allocation_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_revisions far
    where far.fulfilment_allocation_revision_id = v_allocation_revision_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_lines fal
    where fal.fulfilment_allocation_id = v_allocation_id
    order by fal.fulfilment_allocation_line_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
    where falr.fulfilment_allocation_revision_id = v_allocation_revision_id
    order by falr.fulfilment_allocation_line_revision_id for key share;
  perform 1 from atlas_procurement.purchase_orders po
    where po.purchase_order_id in (
      select pol.purchase_order_id
      from atlas_procurement.purchase_order_lines pol
      join atlas_procurement.fulfilment_allocation_lines fal
        on fal.fulfilment_allocation_line_id = pol.fulfilment_allocation_line_id
      where fal.fulfilment_allocation_id = v_allocation_id
    ) order by po.purchase_order_id for key share;
  perform 1 from atlas_procurement.purchase_order_revisions por
    where por.purchase_order_id in (
      select pol.purchase_order_id
      from atlas_procurement.purchase_order_lines pol
      join atlas_procurement.fulfilment_allocation_lines fal
        on fal.fulfilment_allocation_line_id = pol.fulfilment_allocation_line_id
      where fal.fulfilment_allocation_id = v_allocation_id
    ) order by por.purchase_order_revision_id for key share;
  perform 1 from atlas_procurement.purchase_order_lines pol
    where pol.fulfilment_allocation_line_id in (
      select fal.fulfilment_allocation_line_id
      from atlas_procurement.fulfilment_allocation_lines fal
      where fal.fulfilment_allocation_id = v_allocation_id
    ) order by pol.purchase_order_line_id for key share;
  perform 1 from atlas_procurement.purchase_order_line_revisions polr
    where polr.fulfilment_allocation_line_revision_id in (
      select falr.fulfilment_allocation_line_revision_id
      from atlas_procurement.fulfilment_allocation_line_revisions falr
      where falr.fulfilment_allocation_revision_id = v_allocation_revision_id
    ) order by polr.purchase_order_line_revision_id for key share;

  -- Evidence rows named by the exact request.
  perform 1 from atlas_evidence.supplier_receiving_evidence sre
    where sre.supplier_receiving_evidence_id in (
      select ea.supplier_receiving_evidence_id
      from atlas_evidence.evidence_applications ea
      where ea.evidence_application_id in (
        select (application_value ->> 'evidence_application_id')::uuid
        from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
        cross join lateral pg_catalog.jsonb_array_elements(line_value -> 'evidence_applications') application_value
      )
    ) order by sre.supplier_receiving_evidence_id for update;
  perform 1 from atlas_evidence.evidence_applications ea
    where ea.evidence_application_id in (
      select (application_value ->> 'evidence_application_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
      cross join lateral pg_catalog.jsonb_array_elements(line_value -> 'evidence_applications') application_value
    ) order by ea.evidence_application_id for update;

  -- Dispatch roots and any existing consumption are locked last.
  perform 1 from atlas_dispatch.dispatch_plans dp
    where dp.dispatch_plan_id = v_plan_id for key share;
  perform 1 from atlas_dispatch.dispatch_plan_requirements dpr
    where dpr.dispatch_plan_id = v_plan_id
    order by dpr.dispatch_plan_requirement_id for key share;
  perform 1 from atlas_dispatch.dispatch_trips dt
    where dt.dispatch_trip_id = v_trip_id for update;
  perform 1 from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_stop_id = v_stop_id for update;
  perform 1 from atlas_dispatch.dispatch_loads dl
    where dl.dispatch_trip_id = v_trip_id
    order by dl.dispatch_load_id for update;
  perform 1 from atlas_dispatch.dispatch_load_lines dll
    where dll.fulfilment_allocation_line_revision_id in (
      select (line_value ->> 'fulfilment_allocation_line_revision_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
    ) order by dll.dispatch_load_line_id for update;
  perform 1 from atlas_dispatch.dispatch_load_line_applications dlla
    where dlla.evidence_application_id in (
      select (application_value ->> 'evidence_application_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
      cross join lateral pg_catalog.jsonb_array_elements(line_value -> 'evidence_applications') application_value
    ) order by dlla.dispatch_load_line_application_id for update;

  select dt.trip_status, dt.version, dt.driver_actor_id, dt.vehicle_reference,
         ds.stop_status, a.actor_status
    into v_trip_status, v_trip_version, v_driver_actor_id, v_vehicle_reference,
         v_stop_status, v_driver_status
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_stops ds on ds.dispatch_trip_id = dt.dispatch_trip_id
  left join atlas_core.actors a on a.actor_id = dt.driver_actor_id
  where dt.dispatch_trip_id = v_trip_id and ds.dispatch_stop_id = v_stop_id;

  if v_trip_version <> (request ->> 'expected_version')::bigint then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION',
      'The dispatch trip changed. Refresh and review before confirming the load.',
      'DISPATCH', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_trip_id), v_trip_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_trip_status not in ('ASSIGNED', 'LOADED') or v_stop_status <> 'PENDING' then
    v_error := atlas_core.pa_05b_command_error(
      request, 'TRIP_NOT_READY',
      'The trip and selected stop are not eligible for load confirmation.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if (v_driver_actor_id is null and pg_catalog.btrim(coalesce(v_vehicle_reference, '')) = '')
     or (v_driver_actor_id is not null and v_driver_status is distinct from 'ACTIVE') then
    v_error := atlas_core.pa_05b_command_error(
      request, 'TRIP_ASSIGNMENT_REQUIRED',
      'An active driver or non-empty vehicle reference is required before loading.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_loaded_at > pg_catalog.transaction_timestamp() then
    v_error := atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'loaded_at must not be in the future.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1 from atlas_dispatch.dispatch_loads dl
    where dl.dispatch_trip_id = v_trip_id
      and dl.dispatch_requirement_revision_id = v_requirement_revision_id
      and dl.fulfilment_allocation_revision_id = v_allocation_revision_id
      and dl.load_status <> 'VOIDED'
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'A current load already exists for this trip, requirement, and allocation.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_requirement_root_count
  from atlas_planning.dispatch_requirement_lines drl
  where drl.dispatch_requirement_id = v_requirement_id;
  select count(*)::integer into v_requirement_revision_count
  from atlas_planning.dispatch_requirement_line_revisions drlr
  where drlr.dispatch_requirement_revision_id = v_requirement_revision_id;
  select count(*)::integer into v_allocation_root_count
  from atlas_procurement.fulfilment_allocation_lines fal
  where fal.fulfilment_allocation_id = v_allocation_id;
  select count(*)::integer into v_allocation_revision_count
  from atlas_procurement.fulfilment_allocation_line_revisions falr
  where falr.fulfilment_allocation_revision_id = v_allocation_revision_id;
  v_submitted_count := pg_catalog.jsonb_array_length(v_payload -> 'lines');

  with submitted as (
    select (line_value ->> 'dispatch_requirement_line_revision_id')::uuid as requirement_line_revision_id,
           (line_value ->> 'fulfilment_allocation_line_revision_id')::uuid as allocation_line_revision_id,
           (line_value ->> 'loaded_quantity')::numeric as loaded_quantity,
           (line_value ->> 'unit_id')::uuid as unit_id
    from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
  )
  select count(*)::integer into v_valid_count
  from submitted s
  join atlas_planning.dispatch_requirement_line_revisions drlr
    on drlr.dispatch_requirement_line_revision_id = s.requirement_line_revision_id
   and drlr.dispatch_requirement_revision_id = v_requirement_revision_id
  join atlas_planning.dispatch_requirement_lines drl
    on drl.dispatch_requirement_line_id = drlr.dispatch_requirement_line_id
   and drl.dispatch_requirement_id = v_requirement_id
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_revision_id = drlr.dispatch_requirement_revision_id
   and drr.dispatch_requirement_id = drl.dispatch_requirement_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = drr.dispatch_requirement_id
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
  join atlas_procurement.fulfilment_allocation_line_revisions falr
    on falr.fulfilment_allocation_line_revision_id = s.allocation_line_revision_id
   and falr.fulfilment_allocation_revision_id = v_allocation_revision_id
   and falr.dispatch_requirement_line_revision_id = drlr.dispatch_requirement_line_revision_id
  join atlas_procurement.fulfilment_allocation_lines fal
    on fal.fulfilment_allocation_line_id = falr.fulfilment_allocation_line_id
   and fal.fulfilment_allocation_id = v_allocation_id
   and fal.dispatch_requirement_line_id = drl.dispatch_requirement_line_id
   and fal.portion_sequence = 1
  join atlas_procurement.fulfilment_allocation_revisions far
    on far.fulfilment_allocation_revision_id = falr.fulfilment_allocation_revision_id
   and far.fulfilment_allocation_id = fal.fulfilment_allocation_id
  join atlas_procurement.fulfilment_allocations fa
    on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
   and fa.dispatch_requirement_id = dr.dispatch_requirement_id
  join atlas_procurement.purchase_order_line_revisions polr
    on polr.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
  join atlas_procurement.purchase_order_lines pol
    on pol.purchase_order_line_id = polr.purchase_order_line_id
   and pol.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
  join atlas_procurement.purchase_order_revisions por
    on por.purchase_order_revision_id = polr.purchase_order_revision_id
   and por.purchase_order_id = pol.purchase_order_id
  join atlas_procurement.purchase_orders po
    on po.purchase_order_id = por.purchase_order_id
   and po.supplier_id = falr.supplier_id
  join atlas_admin.customers c on c.customer_id = dr.customer_id
  join atlas_admin.delivery_locations loc on loc.delivery_location_id = dr.delivery_location_id
  join atlas_admin.suppliers sup on sup.supplier_id = falr.supplier_id
  join atlas_admin.ingredients i on i.ingredient_id = drlr.ingredient_id
  join atlas_admin.units u on u.unit_id = drlr.unit_id
  where dr.source_of_need = 'WHOLESALE' and dr.requirement_status = 'RELEASED'
    and drr.revision_status = 'RELEASED' and drr.is_current
    and drr.released_by_actor_id is not null and drr.released_at is not null
    and fa.allocation_status = 'READY_FOR_DISPATCH'
    and far.revision_status = 'READY_FOR_DISPATCH' and far.is_current
    and falr.fulfilment_source_type = 'SUPPLIER_PO'
    and falr.line_status = 'READY_FOR_EVIDENCE'
    and po.purchase_order_status = 'RELEASED_TO_SUPPLIER'
    and por.revision_status = 'RELEASED_TO_SUPPLIER' and por.is_current
    and por.released_by_actor_id is not null and por.released_at is not null
    and c.customer_type = 'WHOLESALE' and c.customer_status = 'ACTIVE'
    and loc.customer_id = c.customer_id and loc.location_status = 'ACTIVE'
    and sup.supplier_status = 'ACTIVE'
    and i.ingredient_status = 'ACTIVE' and u.unit_status = 'ACTIVE'
    and phb.handoff_status = 'RELEASED_TO_PROCUREMENT'
    and phr.revision_status = 'RELEASED_TO_PROCUREMENT' and phr.is_current
    and cnb.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
    and cnlr.revision_status = 'RELEASED' and cnlr.is_current
    and wolr.revision_status = 'RELEASED' and wolr.is_current
    and wo.order_status = 'RELEASED'
    and wo.customer_id = dr.customer_id
    and wo.delivery_location_id = dr.delivery_location_id
    and wo.service_date = dr.service_date
    and phlr.delivery_location_id = dr.delivery_location_id
    and phlr.service_date = dr.service_date
    and por.delivery_location_id = dr.delivery_location_id
    and por.service_date = dr.service_date
    and polr.delivery_location_id = dr.delivery_location_id
    and polr.service_date = dr.service_date
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
    and polr.unit_id = s.unit_id
    and wolr.requested_quantity = cnlr.theoretical_quantity
    and cnlr.theoretical_quantity = cnlr.confirmed_quantity
    and cnlr.confirmed_quantity = cnsl.approved_quantity
    and cnsl.approved_quantity = pdr.approved_quantity
    and pdr.approved_quantity = phlr.handoff_quantity
    and phlr.handoff_quantity = drlr.required_quantity
    and drlr.required_quantity = falr.allocated_quantity
    and falr.allocated_quantity = polr.ordered_quantity
    and polr.ordered_quantity = s.loaded_quantity;

  if v_requirement_root_count < 1
     or v_requirement_root_count <> v_requirement_revision_count
     or v_requirement_root_count <> v_allocation_root_count
     or v_requirement_root_count <> v_allocation_revision_count
     or v_requirement_root_count <> v_submitted_count
     or v_requirement_root_count <> v_valid_count then
    v_error := atlas_core.pa_05b_command_error(
      request, 'LOAD_RECONCILIATION_FAILED',
      'The load must cover every and only current requirement and allocation line exactly.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_application_count
  from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
  cross join lateral pg_catalog.jsonb_array_elements(line_value -> 'evidence_applications') application_value;

  with submitted as (
    select (line_value ->> 'fulfilment_allocation_line_revision_id')::uuid as allocation_line_revision_id,
           (line_value ->> 'loaded_quantity')::numeric as loaded_quantity,
           (line_value ->> 'unit_id')::uuid as line_unit_id,
           (application_value ->> 'evidence_application_id')::uuid as evidence_application_id,
           (application_value ->> 'applied_to_load_quantity')::numeric as bridge_quantity,
           (application_value ->> 'unit_id')::uuid as application_unit_id
    from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
    cross join lateral pg_catalog.jsonb_array_elements(line_value -> 'evidence_applications') application_value
  )
  select count(*)::integer into v_valid_application_count
  from submitted s
  join atlas_procurement.fulfilment_allocation_line_revisions falr
    on falr.fulfilment_allocation_line_revision_id = s.allocation_line_revision_id
   and falr.fulfilment_allocation_revision_id = v_allocation_revision_id
  join atlas_planning.dispatch_requirement_line_revisions drlr
    on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
   and drlr.dispatch_requirement_revision_id = v_requirement_revision_id
  join atlas_procurement.purchase_order_line_revisions polr
    on polr.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
   and polr.ingredient_id = drlr.ingredient_id
   and polr.unit_id = falr.unit_id
  join atlas_procurement.purchase_order_revisions por
    on por.purchase_order_revision_id = polr.purchase_order_revision_id
   and por.is_current and por.revision_status = 'RELEASED_TO_SUPPLIER'
  join atlas_procurement.purchase_orders po
    on po.purchase_order_id = por.purchase_order_id
   and po.purchase_order_status = 'RELEASED_TO_SUPPLIER'
   and po.supplier_id = falr.supplier_id
  join atlas_evidence.evidence_applications ea
    on ea.evidence_application_id = s.evidence_application_id
   and ea.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
  join atlas_evidence.supplier_receiving_evidence sre
    on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
   and sre.purchase_order_line_revision_id = polr.purchase_order_line_revision_id
  where ea.application_status = 'VALID' and sre.evidence_status = 'VALID'
    and not exists (
      select 1 from atlas_evidence.evidence_applications successor
      where successor.supersedes_evidence_application_id = ea.evidence_application_id
        and successor.application_status = 'VALID'
    )
    and not exists (
      select 1 from atlas_evidence.supplier_receiving_evidence successor
      where successor.supersedes_evidence_id = sre.supplier_receiving_evidence_id
        and successor.evidence_status = 'VALID'
    )
    and sre.supplier_id = falr.supplier_id
    and sre.ingredient_id = drlr.ingredient_id
    and ea.unit_id = s.line_unit_id and ea.unit_id = s.application_unit_id
    and ea.unit_id = falr.unit_id and ea.unit_id = sre.unit_id
    and s.bridge_quantity > 0
    and sre.occurred_at <= v_loaded_at and ea.occurred_at <= v_loaded_at;

  if v_valid_application_count <> v_application_count
     or exists (
       select 1
       from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
       cross join lateral (
         select coalesce(pg_catalog.sum((application_value ->> 'applied_to_load_quantity')::numeric), 0) as application_total
         from pg_catalog.jsonb_array_elements(line_value -> 'evidence_applications') application_value
       ) totals
       where totals.application_total <> (line_value ->> 'loaded_quantity')::numeric
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'EVIDENCE_INSUFFICIENT',
      'Every load line must be exactly covered by current matching evidence applications.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    with submitted as (
      select (application_value ->> 'evidence_application_id')::uuid as evidence_application_id,
             (application_value ->> 'applied_to_load_quantity')::numeric as bridge_quantity
      from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
      cross join lateral pg_catalog.jsonb_array_elements(line_value -> 'evidence_applications') application_value
    ), existing as (
      select dlla.evidence_application_id,
             pg_catalog.sum(dlla.applied_to_load_quantity) as consumed_quantity
      from atlas_dispatch.dispatch_load_line_applications dlla
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_line_id = dlla.dispatch_load_line_id
      join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
      where dlla.application_status = 'VALID'
        and dll.line_status = 'CONFIRMED' and dl.load_status = 'CONFIRMED'
      group by dlla.evidence_application_id
    )
    select 1 from submitted s
    join atlas_evidence.evidence_applications ea on ea.evidence_application_id = s.evidence_application_id
    left join existing e on e.evidence_application_id = s.evidence_application_id
    where coalesce(e.consumed_quantity, 0) + s.bridge_quantity > ea.applied_quantity
  ) or exists (
    with submitted as (
      select (line_value ->> 'fulfilment_allocation_line_revision_id')::uuid as allocation_line_revision_id,
             (line_value ->> 'loaded_quantity')::numeric as loaded_quantity
      from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
    ), existing as (
      select dll.fulfilment_allocation_line_revision_id,
             pg_catalog.sum(dll.loaded_quantity) as consumed_quantity
      from atlas_dispatch.dispatch_load_lines dll
      join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
      where dll.line_status = 'CONFIRMED' and dl.load_status = 'CONFIRMED'
      group by dll.fulfilment_allocation_line_revision_id
    )
    select 1 from submitted s
    join atlas_procurement.fulfilment_allocation_line_revisions falr
      on falr.fulfilment_allocation_line_revision_id = s.allocation_line_revision_id
    left join existing e
      on e.fulfilment_allocation_line_revision_id = s.allocation_line_revision_id
    where coalesce(e.consumed_quantity, 0) + s.loaded_quantity > falr.allocated_quantity
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'EVIDENCE_INSUFFICIENT',
      'The load would over-consume an allocation or evidence application.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  insert into atlas_dispatch.dispatch_loads (
    dispatch_trip_id, dispatch_requirement_revision_id,
    fulfilment_allocation_revision_id, load_status,
    loaded_by_actor_id, loaded_at
  ) values (
    v_trip_id, v_requirement_revision_id, v_allocation_revision_id,
    'CONFIRMED', v_actor_id, v_loaded_at
  ) returning dispatch_load_id into v_load_id;

  for v_line in
    select line_value,
           (line_value ->> 'dispatch_requirement_line_revision_id')::uuid as requirement_line_revision_id,
           (line_value ->> 'fulfilment_allocation_line_revision_id')::uuid as allocation_line_revision_id,
           (line_value ->> 'loaded_quantity')::numeric as loaded_quantity,
           (line_value ->> 'unit_id')::uuid as unit_id
    from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
    order by (line_value ->> 'fulfilment_allocation_line_revision_id')::uuid
  loop
    select drlr.ingredient_id into v_ingredient_id
    from atlas_planning.dispatch_requirement_line_revisions drlr
    where drlr.dispatch_requirement_line_revision_id = v_line.requirement_line_revision_id;

    insert into atlas_dispatch.dispatch_load_lines (
      dispatch_load_id, dispatch_stop_id,
      dispatch_requirement_line_revision_id,
      fulfilment_allocation_line_revision_id, ingredient_id,
      loaded_quantity, unit_id, command_id
    ) values (
      v_load_id, v_stop_id, v_line.requirement_line_revision_id,
      v_line.allocation_line_revision_id, v_ingredient_id,
      v_line.loaded_quantity, v_line.unit_id,
      (request ->> 'command_id')::uuid
    ) returning dispatch_load_line_id into v_load_line_id;
    v_load_line_ids := v_load_line_ids || pg_catalog.jsonb_build_array(v_load_line_id);

    for v_application in
      select (application_value ->> 'evidence_application_id')::uuid as evidence_application_id,
             (application_value ->> 'applied_to_load_quantity')::numeric as bridge_quantity,
             (application_value ->> 'unit_id')::uuid as unit_id
      from pg_catalog.jsonb_array_elements(v_line.line_value -> 'evidence_applications') application_value
      order by (application_value ->> 'evidence_application_id')::uuid
    loop
      insert into atlas_dispatch.dispatch_load_line_applications (
        dispatch_load_line_id, evidence_application_id,
        applied_to_load_quantity, unit_id
      ) values (
        v_load_line_id, v_application.evidence_application_id,
        v_application.bridge_quantity, v_application.unit_id
      ) returning dispatch_load_line_application_id into v_load_line_application_id;
      v_load_line_application_ids := v_load_line_application_ids ||
        pg_catalog.jsonb_build_array(v_load_line_application_id);
    end loop;
  end loop;

  update atlas_dispatch.dispatch_trips dt
  set trip_status = 'LOADED', version = dt.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where dt.dispatch_trip_id = v_trip_id
  returning version into v_new_trip_version;

  update atlas_dispatch.dispatch_stops ds
  set stop_status = 'LOADED', version = ds.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ds.dispatch_stop_id = v_stop_id
  returning version into v_new_stop_version;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at,
    payload_summary
  ) values (
    'DispatchLoadConfirmed', 'DISPATCH', 'DispatchLoad', v_load_id, 1,
    v_receipt_id, (request ->> 'command_id')::uuid,
    (request ->> 'correlation_id')::uuid, v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'dispatch_stop_id', v_stop_id,
      'dispatch_load_line_ids', v_load_line_ids,
      'dispatch_load_line_application_ids', v_load_line_application_ids,
      'line_count', v_submitted_count,
      'application_count', v_application_count
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version_after, command_receipt_id, command_id, correlation_id,
    actor_id, reason_code, reason_note, after_summary, source_interface,
    occurred_at
  ) values (
    'DispatchLoadConfirmed', 'DISPATCH', 'DispatchLoad', v_load_id, 1,
    v_receipt_id, (request ->> 'command_id')::uuid,
    (request ->> 'correlation_id')::uuid, v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object(
      'status', 'CONFIRMED', 'line_count', v_submitted_count,
      'application_count', v_application_count
    ),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'dispatch_trip_id', v_trip_id,
      'dispatch_stop_id', v_stop_id,
      'dispatch_load_id', v_load_id,
      'dispatch_load_line_ids', v_load_line_ids,
      'dispatch_load_line_application_ids', v_load_line_application_ids
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'dispatch_trip_version', v_new_trip_version,
      'dispatch_stop_version', v_new_stop_version,
      'dispatch_load_version', 1
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Atomic multi-line Dispatch load confirmed.',
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
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
      'The multi-line Dispatch load could not be confirmed safely.',
      'DISPATCH', v_command_name
    );
end;
$$;

reset role;
revoke create on schema atlas_api from atlas_dispatch_command_runtime;
revoke atlas_dispatch_command_runtime from postgres;

grant atlas_dispatch_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_dispatch_command_runtime;
set role atlas_dispatch_command_runtime;

create or replace function atlas_api.confirm_successful_delivery(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'confirm_successful_delivery';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_trip_id uuid;
  v_stop_id uuid;
  v_confirmed_at timestamptz;
  v_plan_id uuid;
  v_trip_status text;
  v_trip_version bigint;
  v_departed_at timestamptz;
  v_stop_status text;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_requirement_revision_id uuid;
  v_load_id uuid;
  v_raw_line_count integer;
  v_submitted_line_count integer;
  v_valid_line_count integer;
  v_confirmation_id uuid;
  v_confirmation_line_id uuid;
  v_confirmation_line_ids jsonb := '[]'::jsonb;
  v_new_stop_version bigint;
  v_new_trip_version bigint;
  v_line record;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05b_h2_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;

  v_trip_id := (v_payload ->> 'dispatch_trip_id')::uuid;
  v_stop_id := (v_payload ->> 'dispatch_stop_id')::uuid;
  v_confirmed_at := (v_payload ->> 'confirmed_at')::timestamptz;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'DISPATCH', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := (v_actor_context ->> 'actor_id')::uuid;

  select dt.dispatch_plan_id, dt.trip_status, dt.version, dt.departed_at,
         ds.stop_status, ds.customer_id, ds.delivery_location_id,
         ds.dispatch_requirement_revision_id
    into v_plan_id, v_trip_status, v_trip_version, v_departed_at,
         v_stop_status, v_customer_id, v_delivery_location_id,
         v_requirement_revision_id
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_stops ds on ds.dispatch_trip_id = dt.dispatch_trip_id
  where dt.dispatch_trip_id = v_trip_id and ds.dispatch_stop_id = v_stop_id;
  if not found then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The trip and stop could not be validated.',
      'DISPATCH', v_command_name
    );
  end if;

  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'delivery_success.confirm', 'DISPATCH', v_command_name,
    v_customer_id, v_delivery_location_id, v_trip_id
  );
  if v_authorization_error is not null then return v_authorization_error; end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'DISPATCH', 'stop:' || v_stop_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := (v_begin ->> 'receipt_id')::uuid;

  perform 1 from atlas_admin.delivery_locations loc
    where loc.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (
      select (line_value ->> 'unit_id')::uuid
      from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
    ) order by u.unit_id for key share;
  perform 1 from atlas_dispatch.dispatch_plans dp
    where dp.dispatch_plan_id = v_plan_id for key share;
  perform 1 from atlas_dispatch.dispatch_plan_requirements dpr
    where dpr.dispatch_plan_id = v_plan_id
      and dpr.dispatch_requirement_revision_id = v_requirement_revision_id
    order by dpr.dispatch_plan_requirement_id for key share;
  perform 1 from atlas_dispatch.dispatch_trips dt
    where dt.dispatch_trip_id = v_trip_id for update;
  perform 1 from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_stop_id = v_stop_id for update;
  perform 1 from atlas_dispatch.dispatch_loads dl
    where dl.dispatch_trip_id = v_trip_id
      and dl.dispatch_requirement_revision_id = v_requirement_revision_id
    order by dl.dispatch_load_id for update;
  perform 1 from atlas_dispatch.dispatch_load_lines dll
    where dll.dispatch_stop_id = v_stop_id
    order by dll.dispatch_load_line_id for update;
  perform 1 from atlas_dispatch.delivery_confirmations dc
    where dc.dispatch_stop_id = v_stop_id
    order by dc.delivery_confirmation_id for update;

  select dt.trip_status, dt.version, dt.departed_at, ds.stop_status
    into v_trip_status, v_trip_version, v_departed_at, v_stop_status
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_stops ds on ds.dispatch_trip_id = dt.dispatch_trip_id
  where dt.dispatch_trip_id = v_trip_id and ds.dispatch_stop_id = v_stop_id;

  if v_trip_version <> (request ->> 'expected_version')::bigint then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION',
      'The dispatch trip changed. Refresh and review before confirming delivery.',
      'DISPATCH', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_trip_id), v_trip_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_departed_at is null
     or v_trip_status not in ('IN_TRANSIT', 'PARTIALLY_DELIVERED')
     or v_stop_status <> 'IN_TRANSIT' then
    v_error := atlas_core.pa_05b_command_error(
      request, 'TRIP_NOT_READY',
      'Successful delivery may be confirmed only for an in-transit stop after departure.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_confirmed_at < v_departed_at
     or v_confirmed_at > pg_catalog.transaction_timestamp() then
    v_error := atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'confirmed_at must be at or after departure and not in the future.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1 from atlas_dispatch.delivery_confirmations dc
    where dc.dispatch_stop_id = v_stop_id
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'A delivery confirmation already exists for this stop.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_raw_line_count
  from atlas_dispatch.dispatch_loads dl
  join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
  where dl.dispatch_trip_id = v_trip_id
    and dl.dispatch_requirement_revision_id = v_requirement_revision_id
    and dl.load_status = 'CONFIRMED'
    and dll.dispatch_stop_id = v_stop_id
    and dll.line_status = 'CONFIRMED';

  select dl.dispatch_load_id into v_load_id
  from atlas_dispatch.dispatch_loads dl
  join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
  where dl.dispatch_trip_id = v_trip_id
    and dl.dispatch_requirement_revision_id = v_requirement_revision_id
    and dl.load_status = 'CONFIRMED'
    and dll.dispatch_stop_id = v_stop_id
    and dll.line_status = 'CONFIRMED'
  order by dl.dispatch_load_id
  limit 1;
  v_submitted_line_count := pg_catalog.jsonb_array_length(v_payload -> 'lines');

  with submitted as (
    select (line_value ->> 'dispatch_load_line_id')::uuid as dispatch_load_line_id,
           (line_value ->> 'delivered_quantity')::numeric as delivered_quantity,
           (line_value ->> 'returned_quantity')::numeric as returned_quantity,
           (line_value ->> 'exception_quantity')::numeric as exception_quantity,
           (line_value ->> 'unit_id')::uuid as unit_id
    from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
  )
  select count(*)::integer into v_valid_line_count
  from submitted s
  join atlas_dispatch.dispatch_load_lines dll
    on dll.dispatch_load_line_id = s.dispatch_load_line_id
   and dll.dispatch_stop_id = v_stop_id
   and dll.line_status = 'CONFIRMED'
  join atlas_dispatch.dispatch_loads dl
    on dl.dispatch_load_id = dll.dispatch_load_id
   and dl.dispatch_trip_id = v_trip_id
   and dl.dispatch_requirement_revision_id = v_requirement_revision_id
   and dl.load_status = 'CONFIRMED'
  where s.delivered_quantity = dll.loaded_quantity
    and s.returned_quantity = 0 and s.exception_quantity = 0
    and s.unit_id = dll.unit_id
    and not exists (
      select 1
      from atlas_dispatch.delivery_confirmation_lines dcl
      where dcl.dispatch_load_line_id = dll.dispatch_load_line_id
    );

  if v_raw_line_count < 1
     or v_raw_line_count <> v_submitted_line_count
     or v_raw_line_count <> v_valid_line_count
     or 1 <> (
       select count(distinct dl.dispatch_load_id)
       from atlas_dispatch.dispatch_loads dl
       join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
       join atlas_dispatch.dispatch_plan_requirements dpr
         on dpr.dispatch_plan_id = v_plan_id
        and dpr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
        and dpr.fulfilment_allocation_revision_id = dl.fulfilment_allocation_revision_id
       where dl.dispatch_trip_id = v_trip_id
         and dl.dispatch_requirement_revision_id = v_requirement_revision_id
         and dl.load_status = 'CONFIRMED'
         and dll.dispatch_stop_id = v_stop_id
         and dll.line_status = 'CONFIRMED'
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DELIVERY_RECONCILIATION_FAILED',
      'Successful delivery must cover every and only current load line exactly.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  insert into atlas_dispatch.delivery_confirmations (
    dispatch_stop_id, revision_number, delivery_outcome,
    confirmed_by_actor_id, confirmed_at, received_by_reference, notes,
    command_id, correlation_id
  ) values (
    v_stop_id, 1, 'DELIVERED', v_actor_id, v_confirmed_at,
    v_payload ->> 'received_by_reference', v_payload ->> 'notes',
    (request ->> 'command_id')::uuid,
    (request ->> 'correlation_id')::uuid
  ) returning delivery_confirmation_id into v_confirmation_id;

  for v_line in
    select (line_value ->> 'dispatch_load_line_id')::uuid as dispatch_load_line_id,
           (line_value ->> 'delivered_quantity')::numeric as delivered_quantity,
           (line_value ->> 'returned_quantity')::numeric as returned_quantity,
           (line_value ->> 'exception_quantity')::numeric as exception_quantity,
           (line_value ->> 'unit_id')::uuid as unit_id
    from pg_catalog.jsonb_array_elements(v_payload -> 'lines') line_value
    order by (line_value ->> 'dispatch_load_line_id')::uuid
  loop
    insert into atlas_dispatch.delivery_confirmation_lines (
      delivery_confirmation_id, dispatch_load_line_id,
      delivered_quantity, returned_quantity, exception_quantity, unit_id
    ) values (
      v_confirmation_id, v_line.dispatch_load_line_id,
      v_line.delivered_quantity, v_line.returned_quantity,
      v_line.exception_quantity, v_line.unit_id
    ) returning delivery_confirmation_line_id into v_confirmation_line_id;
    v_confirmation_line_ids := v_confirmation_line_ids ||
      pg_catalog.jsonb_build_array(v_confirmation_line_id);
  end loop;

  update atlas_dispatch.dispatch_stops ds
  set stop_status = 'DELIVERED', version = ds.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ds.dispatch_stop_id = v_stop_id
  returning version into v_new_stop_version;

  update atlas_dispatch.dispatch_trips dt
  set trip_status = case
        when not exists (
          select 1 from atlas_dispatch.dispatch_stops ds
          where ds.dispatch_trip_id = v_trip_id and ds.stop_status <> 'DELIVERED'
        ) then 'DELIVERED'
        else 'PARTIALLY_DELIVERED'
      end,
      version = dt.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where dt.dispatch_trip_id = v_trip_id
  returning version into v_new_trip_version;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at,
    payload_summary
  ) values (
    'SuccessfulDeliveryConfirmed', 'DISPATCH', 'DeliveryConfirmation', v_confirmation_id,
    v_receipt_id, (request ->> 'command_id')::uuid,
    (request ->> 'correlation_id')::uuid, v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'dispatch_load_id', v_load_id,
      'delivery_confirmation_line_ids', v_confirmation_line_ids,
      'line_count', v_raw_line_count
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    command_receipt_id, command_id, correlation_id, actor_id,
    reason_code, reason_note, after_summary, source_interface, occurred_at
  ) values (
    'SuccessfulDeliveryConfirmed', 'DISPATCH', 'DeliveryConfirmation', v_confirmation_id,
    v_receipt_id, (request ->> 'command_id')::uuid,
    (request ->> 'correlation_id')::uuid, v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('outcome', 'DELIVERED', 'line_count', v_raw_line_count),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'dispatch_trip_id', v_trip_id,
      'dispatch_stop_id', v_stop_id,
      'delivery_confirmation_id', v_confirmation_id,
      'delivery_confirmation_line_ids', v_confirmation_line_ids
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'dispatch_trip_version', v_new_trip_version,
      'dispatch_stop_version', v_new_stop_version
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Atomic multi-line successful delivery confirmed.',
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
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
      'Successful multi-line delivery could not be confirmed safely.',
      'DISPATCH', v_command_name
    );
end;
$$;

reset role;
revoke create on schema atlas_api from atlas_dispatch_command_runtime;
revoke atlas_dispatch_command_runtime from postgres;

comment on function atlas_core.pa_05b_h2_validate_command_request(jsonb, text) is
  'PA-05B-H2 private exact-envelope and nested multi-line request validator.';

grant atlas_dispatch_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_dispatch_command_runtime;
set role atlas_dispatch_command_runtime;

comment on function atlas_api.confirm_dispatch_load(jsonb) is
  'PA-05B-H2.v1 atomically confirms one exact multi-line supplier-direct Dispatch load.';
comment on function atlas_api.record_dispatch_departure(jsonb) is
  'PA-05B-H2.v1 revalidates full trip allocation, load, Evidence, assignment, and every-stop authorization before departure.';
comment on function atlas_api.confirm_successful_delivery(jsonb) is
  'PA-05B-H2.v1 atomically confirms every current load line for one successful stop delivery.';

create or replace function atlas_api.record_dispatch_departure(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'record_dispatch_departure';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_trip_id uuid;
  v_departed_at timestamptz;
  v_plan_id uuid;
  v_trip_status text;
  v_trip_version bigint;
  v_existing_departed_at timestamptz;
  v_driver_actor_id uuid;
  v_vehicle_reference text;
  v_driver_status text;
  v_scope record;
  v_scope_signature jsonb;
  v_locked_scope_signature jsonb;
  v_stop_count integer;
  v_updated_stop_count integer;
  v_new_trip_version bigint;
  v_stop_versions jsonb;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05b_h2_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;

  v_trip_id := (v_payload ->> 'dispatch_trip_id')::uuid;
  v_departed_at := (v_payload ->> 'departed_at')::timestamptz;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'DISPATCH', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := (v_actor_context ->> 'actor_id')::uuid;

  select dt.dispatch_plan_id, dt.trip_status, dt.version, dt.departed_at,
         dt.driver_actor_id, dt.vehicle_reference
    into v_plan_id, v_trip_status, v_trip_version, v_existing_departed_at,
         v_driver_actor_id, v_vehicle_reference
  from atlas_dispatch.dispatch_trips dt
  where dt.dispatch_trip_id = v_trip_id;
  if not found then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The dispatch trip could not be validated.',
      'DISPATCH', v_command_name
    );
  end if;

  select count(*)::integer,
         pg_catalog.jsonb_agg(
           pg_catalog.jsonb_build_object(
             'customer_id', scopes.customer_id,
             'delivery_location_id', scopes.delivery_location_id
           ) order by scopes.customer_id, scopes.delivery_location_id
         )
    into v_stop_count, v_scope_signature
  from (
    select distinct ds.customer_id, ds.delivery_location_id
    from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = v_trip_id
  ) scopes;
  if v_stop_count < 1 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'A trip must contain at least one stop.',
      'DISPATCH', v_command_name
    );
  end if;

  -- Every distinct customer/location/trip tuple is authorized before receipt
  -- registration. The signature is checked again after root locks below.
  for v_scope in
    select distinct ds.customer_id, ds.delivery_location_id
    from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = v_trip_id
    order by ds.customer_id, ds.delivery_location_id
  loop
    v_authorization_error := atlas_core.pa_05b_authorize_actor(
      request, v_actor_id, 'dispatch_departure.record', 'DISPATCH', v_command_name,
      v_scope.customer_id, v_scope.delivery_location_id, v_trip_id
    );
    if v_authorization_error is not null then return v_authorization_error; end if;
  end loop;

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'DISPATCH', 'trip:' || v_trip_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := (v_begin ->> 'receipt_id')::uuid;

  -- Admin/Core references.
  perform 1 from atlas_core.actors a
    where a.actor_id = v_driver_actor_id for key share;
  perform 1 from atlas_admin.customers c
    where c.customer_id in (
      select ds.customer_id from atlas_dispatch.dispatch_stops ds
      where ds.dispatch_trip_id = v_trip_id
    ) order by c.customer_id for key share;
  perform 1 from atlas_admin.delivery_locations loc
    where loc.delivery_location_id in (
      select ds.delivery_location_id from atlas_dispatch.dispatch_stops ds
      where ds.dispatch_trip_id = v_trip_id
    ) order by loc.delivery_location_id for key share;
  perform 1 from atlas_admin.suppliers s
    where s.supplier_id in (
      select falr.supplier_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by s.supplier_id for key share;
  perform 1 from atlas_admin.ingredients i
    where i.ingredient_id in (
      select dll.ingredient_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (
      select dll.unit_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by u.unit_id for key share;

  -- Complete Planning lineage for the selected trip loads.
  perform 1 from atlas_planning.wholesale_orders wo
    where wo.wholesale_order_id in (
      select cnb.wholesale_order_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
      join atlas_planning.purchase_handoff_revisions phr
        on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb
        on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      join atlas_planning.confirmed_need_batches cnb
        on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by wo.wholesale_order_id for key share;
  perform 1 from atlas_planning.wholesale_order_lines wol
    where wol.wholesale_order_id in (
      select cnb.wholesale_order_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_planning.dispatch_requirement_revisions drr on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      join atlas_planning.confirmed_need_batches cnb on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by wol.wholesale_order_line_id for key share;
  perform 1 from atlas_planning.wholesale_order_line_revisions wolr
    where wolr.wholesale_order_line_revision_id in (
      select pdr.wholesale_order_line_revision_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_planning.dispatch_requirement_line_revisions drlr on drlr.dispatch_requirement_line_revision_id = dll.dispatch_requirement_line_revision_id
      join atlas_planning.purchase_demand_references pdr on pdr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by wolr.wholesale_order_line_revision_id for key share;
  perform 1 from atlas_planning.confirmed_need_batches cnb
    where cnb.confirmed_need_batch_id in (
      select phb.confirmed_need_batch_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_planning.dispatch_requirement_revisions drr on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by cnb.confirmed_need_batch_id for key share;
  perform 1 from atlas_planning.confirmed_need_lines cnl
    where cnl.confirmed_need_line_id in (
      select phl.confirmed_need_line_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_planning.dispatch_requirement_line_revisions drlr on drlr.dispatch_requirement_line_revision_id = dll.dispatch_requirement_line_revision_id
      join atlas_planning.dispatch_requirement_lines drl on drl.dispatch_requirement_line_id = drlr.dispatch_requirement_line_id
      join atlas_planning.purchase_handoff_lines phl on phl.purchase_handoff_line_id = drl.purchase_handoff_line_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by cnl.confirmed_need_line_id for key share;
  perform 1 from atlas_planning.confirmed_need_line_revisions cnlr
    where cnlr.confirmed_need_line_revision_id in (
      select phlr.confirmed_need_line_revision_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_planning.dispatch_requirement_line_revisions drlr on drlr.dispatch_requirement_line_revision_id = dll.dispatch_requirement_line_revision_id
      join atlas_planning.purchase_handoff_line_revisions phlr on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by cnlr.confirmed_need_line_revision_id for key share;
  perform 1 from atlas_planning.confirmed_need_approval_snapshots cns
    where cns.confirmed_need_batch_id in (
      select cnb.confirmed_need_batch_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_planning.dispatch_requirement_revisions drr on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      join atlas_planning.purchase_handoff_batches phb on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
      join atlas_planning.confirmed_need_batches cnb on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by cns.confirmed_need_approval_snapshot_id for key share;
  perform 1 from atlas_planning.confirmed_need_snapshot_lines cnsl
    where cnsl.confirmed_need_line_revision_id in (
      select phlr.confirmed_need_line_revision_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_planning.dispatch_requirement_line_revisions drlr on drlr.dispatch_requirement_line_revision_id = dll.dispatch_requirement_line_revision_id
      join atlas_planning.purchase_handoff_line_revisions phlr on phlr.purchase_handoff_line_revision_id = drlr.purchase_handoff_line_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by cnsl.confirmed_need_snapshot_line_id for key share;
  perform 1 from atlas_planning.purchase_handoff_batches phb
    where phb.purchase_handoff_batch_id in (
      select phr.purchase_handoff_batch_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_planning.dispatch_requirement_revisions drr on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
      join atlas_planning.purchase_handoff_revisions phr on phr.purchase_handoff_revision_id = drr.purchase_handoff_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by phb.purchase_handoff_batch_id for key share;
  perform 1 from atlas_planning.purchase_handoff_revisions phr
    where phr.purchase_handoff_revision_id in (
      select drr.purchase_handoff_revision_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_planning.dispatch_requirement_revisions drr on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by phr.purchase_handoff_revision_id for key share;
  perform 1 from atlas_planning.purchase_handoff_lines phl
    where phl.purchase_handoff_line_id in (
      select drl.purchase_handoff_line_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_planning.dispatch_requirement_line_revisions drlr on drlr.dispatch_requirement_line_revision_id = dll.dispatch_requirement_line_revision_id
      join atlas_planning.dispatch_requirement_lines drl on drl.dispatch_requirement_line_id = drlr.dispatch_requirement_line_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by phl.purchase_handoff_line_id for key share;
  perform 1 from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_line_revision_id in (
      select drlr.purchase_handoff_line_revision_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_planning.dispatch_requirement_line_revisions drlr on drlr.dispatch_requirement_line_revision_id = dll.dispatch_requirement_line_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by phlr.purchase_handoff_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_demand_references pdr
    where pdr.purchase_handoff_line_revision_id in (
      select drlr.purchase_handoff_line_revision_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_planning.dispatch_requirement_line_revisions drlr on drlr.dispatch_requirement_line_revision_id = dll.dispatch_requirement_line_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by pdr.purchase_demand_reference_id for key share;
  perform 1 from atlas_planning.dispatch_requirements dr
    where dr.dispatch_requirement_id in (
      select drr.dispatch_requirement_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_planning.dispatch_requirement_revisions drr on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by dr.dispatch_requirement_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_revisions drr
    where drr.dispatch_requirement_revision_id in (
      select dl.dispatch_requirement_revision_id from atlas_dispatch.dispatch_loads dl
      where dl.dispatch_trip_id = v_trip_id
    ) order by drr.dispatch_requirement_revision_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_lines drl
    where drl.dispatch_requirement_id in (
      select drr.dispatch_requirement_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_planning.dispatch_requirement_revisions drr on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by drl.dispatch_requirement_line_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_line_revisions drlr
    where drlr.dispatch_requirement_revision_id in (
      select dl.dispatch_requirement_revision_id from atlas_dispatch.dispatch_loads dl
      where dl.dispatch_trip_id = v_trip_id
    ) order by drlr.dispatch_requirement_line_revision_id for key share;

  -- Procurement and supplier-PO lineage.
  perform 1 from atlas_procurement.fulfilment_allocations fa
    where fa.fulfilment_allocation_id in (
      select far.fulfilment_allocation_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_procurement.fulfilment_allocation_revisions far on far.fulfilment_allocation_revision_id = dl.fulfilment_allocation_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by fa.fulfilment_allocation_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_revisions far
    where far.fulfilment_allocation_revision_id in (
      select dl.fulfilment_allocation_revision_id from atlas_dispatch.dispatch_loads dl
      where dl.dispatch_trip_id = v_trip_id
    ) order by far.fulfilment_allocation_revision_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_lines fal
    where fal.fulfilment_allocation_line_id in (
      select falr.fulfilment_allocation_line_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_procurement.fulfilment_allocation_line_revisions falr on falr.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by fal.fulfilment_allocation_line_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
    where falr.fulfilment_allocation_line_revision_id in (
      select dll.fulfilment_allocation_line_revision_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by falr.fulfilment_allocation_line_revision_id for key share;
  perform 1 from atlas_procurement.purchase_orders po
    where po.purchase_order_id in (
      select por.purchase_order_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_procurement.purchase_order_line_revisions polr on polr.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
      join atlas_procurement.purchase_order_revisions por on por.purchase_order_revision_id = polr.purchase_order_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by po.purchase_order_id for key share;
  perform 1 from atlas_procurement.purchase_order_revisions por
    where por.purchase_order_revision_id in (
      select polr.purchase_order_revision_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_procurement.purchase_order_line_revisions polr on polr.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by por.purchase_order_revision_id for key share;
  perform 1 from atlas_procurement.purchase_order_lines pol
    where pol.purchase_order_line_id in (
      select polr.purchase_order_line_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_procurement.purchase_order_line_revisions polr on polr.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by pol.purchase_order_line_id for key share;
  perform 1 from atlas_procurement.purchase_order_line_revisions polr
    where polr.fulfilment_allocation_line_revision_id in (
      select dll.fulfilment_allocation_line_revision_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by polr.purchase_order_line_revision_id for key share;

  -- Evidence and application rows.
  perform 1 from atlas_evidence.supplier_receiving_evidence sre
    where sre.supplier_receiving_evidence_id in (
      select ea.supplier_receiving_evidence_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_dispatch.dispatch_load_line_applications dlla on dlla.dispatch_load_line_id = dll.dispatch_load_line_id
      join atlas_evidence.evidence_applications ea on ea.evidence_application_id = dlla.evidence_application_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by sre.supplier_receiving_evidence_id for update;
  perform 1 from atlas_evidence.evidence_applications ea
    where ea.evidence_application_id in (
      select dlla.evidence_application_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      join atlas_dispatch.dispatch_load_line_applications dlla on dlla.dispatch_load_line_id = dll.dispatch_load_line_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by ea.evidence_application_id for update;

  -- Dispatch roots and children are locked last.
  perform 1 from atlas_dispatch.dispatch_plans dp
    where dp.dispatch_plan_id = v_plan_id for key share;
  perform 1 from atlas_dispatch.dispatch_plan_requirements dpr
    where dpr.dispatch_plan_id = v_plan_id
    order by dpr.dispatch_plan_requirement_id for key share;
  perform 1 from atlas_dispatch.dispatch_trips dt
    where dt.dispatch_trip_id = v_trip_id for update;
  perform 1 from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = v_trip_id order by ds.dispatch_stop_id for update;
  perform 1 from atlas_dispatch.dispatch_loads dl
    where dl.dispatch_trip_id = v_trip_id order by dl.dispatch_load_id for update;
  perform 1 from atlas_dispatch.dispatch_load_lines dll
    where dll.dispatch_load_id in (
      select dl.dispatch_load_id from atlas_dispatch.dispatch_loads dl
      where dl.dispatch_trip_id = v_trip_id
    ) order by dll.dispatch_load_line_id for update;
  perform 1 from atlas_dispatch.dispatch_load_line_applications dlla
    where dlla.dispatch_load_line_id in (
      select dll.dispatch_load_line_id
      from atlas_dispatch.dispatch_loads dl
      join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
      where dl.dispatch_trip_id = v_trip_id
    ) order by dlla.dispatch_load_line_application_id for update;

  select dt.trip_status, dt.version, dt.departed_at,
         dt.driver_actor_id, dt.vehicle_reference, a.actor_status
    into v_trip_status, v_trip_version, v_existing_departed_at,
         v_driver_actor_id, v_vehicle_reference, v_driver_status
  from atlas_dispatch.dispatch_trips dt
  left join atlas_core.actors a on a.actor_id = dt.driver_actor_id
  where dt.dispatch_trip_id = v_trip_id;

  select pg_catalog.jsonb_agg(
           pg_catalog.jsonb_build_object(
             'customer_id', scopes.customer_id,
             'delivery_location_id', scopes.delivery_location_id
           ) order by scopes.customer_id, scopes.delivery_location_id
         )
    into v_locked_scope_signature
  from (
    select distinct ds.customer_id, ds.delivery_location_id
    from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = v_trip_id
  ) scopes;

  if v_locked_scope_signature is distinct from v_scope_signature then
    v_error := atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'Trip stop scope changed during authorization. Retry the exact request.',
      'DISPATCH', v_command_name, true
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_trip_version <> (request ->> 'expected_version')::bigint then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION',
      'The dispatch trip changed. Refresh and review before departure.',
      'DISPATCH', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_trip_id), v_trip_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_trip_status <> 'LOADED' or v_existing_departed_at is not null then
    v_error := atlas_core.pa_05b_command_error(
      request, 'TRIP_NOT_READY', 'The trip is not in a departure-eligible loaded state.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if (v_driver_actor_id is null and pg_catalog.btrim(coalesce(v_vehicle_reference, '')) = '')
     or (v_driver_actor_id is not null and v_driver_status is distinct from 'ACTIVE') then
    v_error := atlas_core.pa_05b_command_error(
      request, 'TRIP_ASSIGNMENT_REQUIRED',
      'An active driver or non-empty vehicle reference is required before departure.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_departed_at > pg_catalog.transaction_timestamp()
     or exists (
       select 1 from atlas_dispatch.dispatch_loads dl
       where dl.dispatch_trip_id = v_trip_id and dl.load_status = 'CONFIRMED'
         and dl.loaded_at > v_departed_at
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'departed_at must be at or after every confirmed load and not in the future.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1 from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = v_trip_id
      and (
        ds.stop_status <> 'LOADED'
        or 1 <> (
          select count(*)
          from atlas_dispatch.dispatch_plan_requirements dpr
          where dpr.dispatch_plan_id = v_plan_id
            and dpr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
        )
        or 1 <> (
          select count(distinct dl.dispatch_load_id)
          from atlas_dispatch.dispatch_plan_requirements dpr
          join atlas_dispatch.dispatch_loads dl
            on dl.dispatch_trip_id = v_trip_id
           and dl.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
           and dl.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
           and dl.load_status = 'CONFIRMED'
          where dpr.dispatch_plan_id = v_plan_id
            and dpr.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
            and exists (
              select 1 from atlas_dispatch.dispatch_load_lines dll
              where dll.dispatch_load_id = dl.dispatch_load_id
                and dll.dispatch_stop_id = ds.dispatch_stop_id
            )
        )
      )
  ) or exists (
    select 1 from atlas_dispatch.dispatch_loads dl
    where dl.dispatch_trip_id = v_trip_id and dl.load_status = 'CONFIRMED'
      and not exists (
        select 1
        from atlas_dispatch.dispatch_plan_requirements dpr
        join atlas_dispatch.dispatch_stops ds
          on ds.dispatch_trip_id = v_trip_id
         and ds.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
        where dpr.dispatch_plan_id = v_plan_id
          and dpr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
          and dpr.fulfilment_allocation_revision_id = dl.fulfilment_allocation_revision_id
          and 1 = (
            select count(distinct dll.dispatch_stop_id)
            from atlas_dispatch.dispatch_load_lines dll
            where dll.dispatch_load_id = dl.dispatch_load_id
          )
          and exists (
            select 1 from atlas_dispatch.dispatch_load_lines dll
            where dll.dispatch_load_id = dl.dispatch_load_id
              and dll.dispatch_stop_id = ds.dispatch_stop_id
          )
      )
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DEPARTURE_BLOCKED',
      'Every stop must have exactly one compatible current load and no extra trip load may exist.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  -- Raw load lines, current allocation children, and fully valid exact-lineage
  -- load lines must have identical cardinality for every selected-trip load.
  if exists (
    select 1
    from atlas_dispatch.dispatch_loads dl
    join atlas_procurement.fulfilment_allocation_revisions far
      on far.fulfilment_allocation_revision_id = dl.fulfilment_allocation_revision_id
    left join lateral (
      select count(*)::integer as raw_count
      from atlas_dispatch.dispatch_load_lines dll
      where dll.dispatch_load_id = dl.dispatch_load_id
    ) raw_load on true
    left join lateral (
      select count(*)::integer as stable_count
      from atlas_procurement.fulfilment_allocation_lines fal
      where fal.fulfilment_allocation_id = far.fulfilment_allocation_id
    ) stable_allocation on true
    left join lateral (
      select count(*)::integer as revision_count
      from atlas_procurement.fulfilment_allocation_line_revisions falr
      where falr.fulfilment_allocation_revision_id = dl.fulfilment_allocation_revision_id
    ) revision_allocation on true
    left join lateral (
      select count(*)::integer as valid_count
      from atlas_dispatch.dispatch_load_lines dll
      join atlas_planning.dispatch_requirement_line_revisions drlr
        on drlr.dispatch_requirement_line_revision_id = dll.dispatch_requirement_line_revision_id
       and drlr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
      join atlas_planning.dispatch_requirement_lines drl
        on drl.dispatch_requirement_line_id = drlr.dispatch_requirement_line_id
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.dispatch_requirement_revision_id = drlr.dispatch_requirement_revision_id
       and drr.dispatch_requirement_id = drl.dispatch_requirement_id
      join atlas_planning.dispatch_requirements dr
        on dr.dispatch_requirement_id = drr.dispatch_requirement_id
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
      join atlas_planning.confirmed_need_lines cnl on cnl.confirmed_need_line_id = phl.confirmed_need_line_id
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
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
       and falr.fulfilment_allocation_revision_id = dl.fulfilment_allocation_revision_id
       and falr.dispatch_requirement_line_revision_id = drlr.dispatch_requirement_line_revision_id
      join atlas_procurement.fulfilment_allocation_lines fal
        on fal.fulfilment_allocation_line_id = falr.fulfilment_allocation_line_id
       and fal.fulfilment_allocation_id = far.fulfilment_allocation_id
       and fal.dispatch_requirement_line_id = drl.dispatch_requirement_line_id
       and fal.portion_sequence = 1
      join atlas_procurement.fulfilment_allocations fa
        on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
       and fa.dispatch_requirement_id = dr.dispatch_requirement_id
      join atlas_procurement.purchase_order_line_revisions polr
        on polr.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
      join atlas_procurement.purchase_order_lines pol
        on pol.purchase_order_line_id = polr.purchase_order_line_id
       and pol.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
      join atlas_procurement.purchase_order_revisions por
        on por.purchase_order_revision_id = polr.purchase_order_revision_id
       and por.purchase_order_id = pol.purchase_order_id
      join atlas_procurement.purchase_orders po
        on po.purchase_order_id = por.purchase_order_id
       and po.supplier_id = falr.supplier_id
      join atlas_admin.customers c on c.customer_id = dr.customer_id
      join atlas_admin.delivery_locations loc on loc.delivery_location_id = dr.delivery_location_id
      join atlas_admin.suppliers sup on sup.supplier_id = falr.supplier_id
      join atlas_admin.ingredients i on i.ingredient_id = drlr.ingredient_id
      join atlas_admin.units u on u.unit_id = drlr.unit_id
      where dll.dispatch_load_id = dl.dispatch_load_id
        and dll.line_status = 'CONFIRMED'
        and dr.source_of_need = 'WHOLESALE' and dr.requirement_status = 'RELEASED'
        and drr.revision_status = 'RELEASED' and drr.is_current
        and drr.released_by_actor_id is not null and drr.released_at is not null
        and fa.allocation_status = 'READY_FOR_DISPATCH'
        and far.revision_status = 'READY_FOR_DISPATCH' and far.is_current
        and falr.fulfilment_source_type = 'SUPPLIER_PO'
        and falr.line_status = 'READY_FOR_EVIDENCE'
        and po.purchase_order_status = 'RELEASED_TO_SUPPLIER'
        and por.revision_status = 'RELEASED_TO_SUPPLIER' and por.is_current
        and por.released_by_actor_id is not null and por.released_at is not null
        and c.customer_type = 'WHOLESALE' and c.customer_status = 'ACTIVE'
        and loc.customer_id = c.customer_id and loc.location_status = 'ACTIVE'
        and sup.supplier_status = 'ACTIVE'
        and i.ingredient_status = 'ACTIVE' and u.unit_status = 'ACTIVE'
        and phb.handoff_status = 'RELEASED_TO_PROCUREMENT'
        and phr.revision_status = 'RELEASED_TO_PROCUREMENT' and phr.is_current
        and cnb.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
        and cnlr.revision_status = 'RELEASED' and cnlr.is_current
        and wolr.revision_status = 'RELEASED' and wolr.is_current
        and wo.order_status = 'RELEASED'
        and wo.customer_id = dr.customer_id
        and wo.delivery_location_id = dr.delivery_location_id
        and wo.service_date = dr.service_date
        and phlr.delivery_location_id = dr.delivery_location_id
        and phlr.service_date = dr.service_date
        and por.delivery_location_id = dr.delivery_location_id
        and por.service_date = dr.service_date
        and polr.delivery_location_id = dr.delivery_location_id
        and polr.service_date = dr.service_date
        and dll.ingredient_id = drlr.ingredient_id
        and drlr.ingredient_id = phlr.ingredient_id
        and phlr.ingredient_id = cnlr.ingredient_id
        and cnlr.ingredient_id = cnsl.ingredient_id
        and cnsl.ingredient_id = wolr.ingredient_id
        and wolr.ingredient_id = polr.ingredient_id
        and dll.unit_id = drlr.unit_id
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
        and polr.ordered_quantity = dll.loaded_quantity
    ) valid_load on true
    where dl.dispatch_trip_id = v_trip_id and dl.load_status = 'CONFIRMED'
      and (
        raw_load.raw_count < 1
        or raw_load.raw_count <> stable_allocation.stable_count
        or raw_load.raw_count <> revision_allocation.revision_count
        or raw_load.raw_count <> valid_load.valid_count
      )
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DEPARTURE_BLOCKED',
      'Every load must retain complete exact allocation-line and supplier-PO lineage.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_dispatch.dispatch_loads dl
    join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
    left join lateral (
      select count(*)::integer as raw_count
      from atlas_dispatch.dispatch_load_line_applications dlla
      where dlla.dispatch_load_line_id = dll.dispatch_load_line_id
    ) raw_bridge on true
    left join lateral (
      select count(*)::integer as valid_count,
             coalesce(pg_catalog.sum(dlla.applied_to_load_quantity), 0) as valid_quantity
      from atlas_dispatch.dispatch_load_line_applications dlla
      join atlas_evidence.evidence_applications ea
        on ea.evidence_application_id = dlla.evidence_application_id
       and ea.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
      join atlas_evidence.supplier_receiving_evidence sre
        on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
      join atlas_procurement.purchase_order_line_revisions polr
        on polr.purchase_order_line_revision_id = sre.purchase_order_line_revision_id
       and polr.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
       and polr.ingredient_id = dll.ingredient_id
       and polr.unit_id = dll.unit_id
      join atlas_procurement.purchase_order_revisions por
        on por.purchase_order_revision_id = polr.purchase_order_revision_id
       and por.is_current and por.revision_status = 'RELEASED_TO_SUPPLIER'
      join atlas_procurement.purchase_orders po
        on po.purchase_order_id = por.purchase_order_id
       and po.purchase_order_status = 'RELEASED_TO_SUPPLIER'
       and po.supplier_id = sre.supplier_id
      join atlas_procurement.fulfilment_allocation_line_revisions falr
        on falr.fulfilment_allocation_line_revision_id = dll.fulfilment_allocation_line_revision_id
       and falr.supplier_id = sre.supplier_id
       and falr.unit_id = dll.unit_id
      where dlla.dispatch_load_line_id = dll.dispatch_load_line_id
        and dlla.application_status = 'VALID'
        and ea.application_status = 'VALID'
        and sre.evidence_status = 'VALID'
        and dlla.unit_id = dll.unit_id
        and ea.unit_id = dll.unit_id and sre.unit_id = dll.unit_id
        and sre.ingredient_id = dll.ingredient_id
        and sre.occurred_at <= dl.loaded_at and ea.occurred_at <= dl.loaded_at
        and not exists (
          select 1 from atlas_evidence.evidence_applications successor
          where successor.supersedes_evidence_application_id = ea.evidence_application_id
            and successor.application_status = 'VALID'
        )
        and not exists (
          select 1 from atlas_evidence.supplier_receiving_evidence successor
          where successor.supersedes_evidence_id = sre.supplier_receiving_evidence_id
            and successor.evidence_status = 'VALID'
        )
    ) valid_bridge on true
    where dl.dispatch_trip_id = v_trip_id
      and dl.load_status = 'CONFIRMED' and dll.line_status = 'CONFIRMED'
      and (
        raw_bridge.raw_count < 1
        or raw_bridge.raw_count <> valid_bridge.valid_count
        or valid_bridge.valid_quantity <> dll.loaded_quantity
      )
  ) or exists (
    select 1
    from atlas_evidence.evidence_applications ea
    join atlas_dispatch.dispatch_load_line_applications relevant
      on relevant.evidence_application_id = ea.evidence_application_id
    join atlas_dispatch.dispatch_load_lines relevant_line
      on relevant_line.dispatch_load_line_id = relevant.dispatch_load_line_id
    join atlas_dispatch.dispatch_loads relevant_load
      on relevant_load.dispatch_load_id = relevant_line.dispatch_load_id
    where relevant_load.dispatch_trip_id = v_trip_id
    group by ea.evidence_application_id, ea.applied_quantity
    having (
      select coalesce(pg_catalog.sum(all_bridge.applied_to_load_quantity), 0)
      from atlas_dispatch.dispatch_load_line_applications all_bridge
      join atlas_dispatch.dispatch_load_lines all_line on all_line.dispatch_load_line_id = all_bridge.dispatch_load_line_id
      join atlas_dispatch.dispatch_loads all_load on all_load.dispatch_load_id = all_line.dispatch_load_id
      where all_bridge.evidence_application_id = ea.evidence_application_id
        and all_bridge.application_status = 'VALID'
        and all_line.line_status = 'CONFIRMED' and all_load.load_status = 'CONFIRMED'
    ) > ea.applied_quantity
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DEPARTURE_BLOCKED',
      'Every load line must remain exactly covered by valid, unconsumed evidence.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  update atlas_dispatch.dispatch_trips dt
  set trip_status = 'IN_TRANSIT', departed_at = v_departed_at,
      version = dt.version + 1, updated_at = pg_catalog.transaction_timestamp()
  where dt.dispatch_trip_id = v_trip_id
  returning version into v_new_trip_version;

  update atlas_dispatch.dispatch_stops ds
  set stop_status = 'IN_TRANSIT', version = ds.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ds.dispatch_trip_id = v_trip_id and ds.stop_status = 'LOADED';
  get diagnostics v_updated_stop_count = row_count;
  if v_updated_stop_count <> (
    select count(*)::integer from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = v_trip_id
  ) then
    raise exception using errcode = '40001', message = 'trip stop set changed during departure';
  end if;

  select pg_catalog.jsonb_object_agg(ds.dispatch_stop_id::text, ds.version)
    into v_stop_versions
  from atlas_dispatch.dispatch_stops ds
  where ds.dispatch_trip_id = v_trip_id;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at,
    payload_summary
  ) values (
    'DispatchDeparted', 'DISPATCH', 'DispatchTrip', v_trip_id, v_new_trip_version,
    v_receipt_id, (request ->> 'command_id')::uuid,
    (request ->> 'correlation_id')::uuid, v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'departed_at', v_departed_at,
      'dispatch_stop_versions', v_stop_versions
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version_before, aggregate_version_after, command_receipt_id,
    command_id, correlation_id, actor_id, reason_code, reason_note,
    before_summary, after_summary, source_interface, occurred_at
  ) values (
    'DispatchDeparted', 'DISPATCH', 'DispatchTrip', v_trip_id,
    v_trip_version, v_new_trip_version, v_receipt_id,
    (request ->> 'command_id')::uuid,
    (request ->> 'correlation_id')::uuid, v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status', 'LOADED'),
    pg_catalog.jsonb_build_object(
      'status', 'IN_TRANSIT', 'departed_at', v_departed_at,
      'stop_count', v_updated_stop_count
    ),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'dispatch_trip_id', v_trip_id,
      'dispatch_stop_ids', (
        select pg_catalog.jsonb_agg(ds.dispatch_stop_id order by ds.dispatch_stop_id)
        from atlas_dispatch.dispatch_stops ds where ds.dispatch_trip_id = v_trip_id
      )
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'dispatch_trip_version', v_new_trip_version,
      'dispatch_stop_versions', v_stop_versions
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Dispatch departure recorded after full trip revalidation.',
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
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
      'Dispatch departure could not be recorded safely.',
      'DISPATCH', v_command_name
    );
end;
$$;

reset role;
revoke create on schema atlas_api from atlas_dispatch_command_runtime;
revoke atlas_dispatch_command_runtime from postgres;
