-- PA-05B: bounded supplier-direct evidence-to-delivery command subset.
--
-- This migration adds only reviewed function entry points in atlas_api,
-- private helper functions, runtime-only grants/RLS policies, and no seed or
-- production data. The authoritative PA-04 domain tables remain private.

create or replace function atlas_core.pa_05b_safe_uuid(value text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  if value is null or pg_catalog.btrim(value) = '' then
    return null;
  end if;

  return value::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

create or replace function atlas_core.pa_05b_safe_bigint(value text)
returns bigint
language plpgsql
immutable
set search_path = ''
as $$
begin
  if value is null or pg_catalog.btrim(value) = '' then
    return null;
  end if;

  return value::bigint;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    return null;
end;
$$;

create or replace function atlas_core.pa_05b_safe_numeric(value text)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
begin
  if value is null or pg_catalog.btrim(value) = '' then
    return null;
  end if;

  return value::numeric;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    return null;
end;
$$;

create or replace function atlas_core.pa_05b_safe_timestamptz(value text)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
begin
  if value is null or pg_catalog.btrim(value) = '' then
    return null;
  end if;

  return value::timestamptz;
exception
  when invalid_datetime_format or datetime_field_overflow then
    return null;
end;
$$;

create or replace function atlas_core.pa_05b_current_auth_subject()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_subject text;
begin
  v_subject := nullif(
    pg_catalog.current_setting('request.jwt.claim.sub', true),
    ''
  );

  if v_subject is null then
    begin
      v_subject := (
        pg_catalog.current_setting('request.jwt.claims', true)::jsonb
      ) ->> 'sub';
    exception
      when others then
        v_subject := null;
    end;
  end if;

  return atlas_core.pa_05b_safe_uuid(v_subject);
end;
$$;

create or replace function atlas_core.pa_05b_command_error(
  request jsonb,
  error_code text,
  safe_message text,
  domain_name text,
  command_name text,
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
  select pg_catalog.jsonb_build_object(
    'success', false,
    'error_code', error_code,
    'safe_message', safe_message,
    'domain', domain_name,
    'command_name', command_name,
    'retryable', retryable,
    'field_errors', coalesce(field_errors, '[]'::jsonb),
    'blocking_references', coalesce(blocking_references, '[]'::jsonb),
    'expected_version', atlas_core.pa_05b_safe_bigint(request ->> 'expected_version'),
    'actual_version', actual_version,
    'correlation_id', request ->> 'correlation_id',
    'command_id', request ->> 'command_id'
  );
$$;

create or replace function atlas_core.pa_05b_validate_command_request(
  request jsonb,
  domain_name text,
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
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb),
      'VALIDATION_FAILED',
      'The command request must be a JSON object.',
      domain_name,
      command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'request', 'message', 'A JSON object is required.')
      )
    );
  end if;

  if request ->> 'contract_version' is distinct from 'PA-05B.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use PA-05B.v1.')
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

  if not (request ? 'reason_note') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'reason_note', 'message', 'The reason_note field is required and may be null.')
    );
  end if;

  if request -> 'payload' is null or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'A JSON object is required.')
    );
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The command envelope is invalid.',
      domain_name,
      command_name,
      false,
      v_errors
    );
  end if;

  return null;
end;
$$;

create or replace function atlas_core.pa_05b_resolve_actor(
  request jsonb,
  domain_name text,
  command_name text
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_authenticated_subject uuid;
  v_requested_subject uuid;
  v_actor_id uuid;
  v_actor_type text;
  v_actor_status text;
  v_subject_status text;
begin
  v_authenticated_subject := atlas_core.pa_05b_current_auth_subject();
  v_requested_subject := atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject');

  if v_authenticated_subject is null then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.pa_05b_command_error(
        request,
        'AUTHENTICATION_REQUIRED',
        'An authenticated Atlas subject is required.',
        domain_name,
        command_name
      )
    );
  end if;

  if v_requested_subject is distinct from v_authenticated_subject then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.pa_05b_command_error(
        request,
        'AUTH_SUBJECT_MISMATCH',
        'The asserted authentication subject does not match the current session.',
        domain_name,
        command_name
      )
    );
  end if;

  select
    aas.actor_id,
    aas.subject_status,
    a.actor_type,
    a.actor_status
  into
    v_actor_id,
    v_subject_status,
    v_actor_type,
    v_actor_status
  from atlas_core.actor_auth_subjects aas
  join atlas_core.actors a on a.actor_id = aas.actor_id
  where aas.auth_provider = 'SUPABASE_AUTH'
    and aas.auth_subject_id = v_authenticated_subject;

  if not found then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.pa_05b_command_error(
        request,
        'ACTOR_NOT_FOUND',
        'No Atlas actor is registered for the authenticated subject.',
        domain_name,
        command_name
      )
    );
  end if;

  if v_subject_status <> 'ACTIVE' then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.pa_05b_command_error(
        request,
        'AUTH_SUBJECT_INACTIVE',
        'The Atlas authentication subject is inactive.',
        domain_name,
        command_name
      )
    );
  end if;

  if v_actor_status <> 'ACTIVE' then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.pa_05b_command_error(
        request,
        'ACTOR_INACTIVE',
        'The Atlas actor is inactive.',
        domain_name,
        command_name
      )
    );
  end if;

  if v_actor_type not in ('HUMAN', 'INTEGRATION')
     or coalesce(request -> 'payload' ->> 'delegated_actor_id', '') <> ''
     or coalesce(request -> 'payload' ->> 'management_override_id', '') <> ''
     or coalesce(request -> 'payload' ->> 'approval_id', '') <> '' then
    return pg_catalog.jsonb_build_object(
      'error', atlas_core.pa_05b_command_error(
        request,
        'DELEGATION_NOT_SUPPORTED',
        'Delegation and management override are not implemented in PA-05B.',
        domain_name,
        command_name
      )
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'actor_id', v_actor_id,
    'actor_type', v_actor_type
  );
end;
$$;

create or replace function atlas_core.pa_05b_authorize_actor(
  request jsonb,
  actor_id uuid,
  capability_code text,
  domain_name text,
  command_name text,
  customer_id uuid default null,
  delivery_location_id uuid default null,
  dispatch_trip_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from atlas_core.actor_role_memberships arm
    join atlas_core.roles r on r.role_id = arm.role_id
    join atlas_core.role_capabilities rc on rc.role_id = r.role_id
    join atlas_core.capabilities c on c.capability_id = rc.capability_id
    where arm.actor_id = pa_05b_authorize_actor.actor_id
      and arm.membership_status = 'ACTIVE'
      and arm.effective_from <= pg_catalog.transaction_timestamp()
      and (arm.effective_to is null or arm.effective_to > pg_catalog.transaction_timestamp())
      and r.role_status = 'ACTIVE'
      and c.capability_status = 'ACTIVE'
      and c.capability_code = pa_05b_authorize_actor.capability_code
  ) then
    return atlas_core.pa_05b_command_error(
      request,
      'CAPABILITY_DENIED',
      'The actor does not have the required capability.',
      domain_name,
      command_name
    );
  end if;

  if not exists (
    select 1
    from atlas_core.actor_scopes s
    where s.actor_id = pa_05b_authorize_actor.actor_id
      and s.scope_status = 'ACTIVE'
      and s.effective_from <= pg_catalog.transaction_timestamp()
      and (s.effective_to is null or s.effective_to > pg_catalog.transaction_timestamp())
      and (
        s.scope_kind = 'GLOBAL'
        or (s.scope_kind = 'CUSTOMER' and s.customer_id = pa_05b_authorize_actor.customer_id)
        or (
          s.scope_kind = 'DELIVERY_LOCATION'
          and s.delivery_location_id = pa_05b_authorize_actor.delivery_location_id
        )
        or (s.scope_kind = 'DISPATCH_TRIP' and s.dispatch_trip_id = pa_05b_authorize_actor.dispatch_trip_id)
      )
  ) then
    return atlas_core.pa_05b_command_error(
      request,
      'SCOPE_DENIED',
      'The actor is outside the required Atlas scope.',
      domain_name,
      command_name
    );
  end if;

  return null;
end;
$$;

create or replace function atlas_core.pa_05b_request_hash(request jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.encode(
    pg_catalog.sha256(
      pg_catalog.convert_to(
        pg_catalog.jsonb_build_object(
          'contract_version', request -> 'contract_version',
          'command_id', request -> 'command_id',
          'idempotency_key', request -> 'idempotency_key',
          'expected_version', request -> 'expected_version',
          'requested_by_auth_subject', request -> 'requested_by_auth_subject',
          'reason_code', request -> 'reason_code',
          'reason_note', request -> 'reason_note',
          'payload', request -> 'payload'
        )::text,
        'UTF8'
      )
    ),
    'hex'
  );
$$;

create or replace function atlas_core.pa_05b_begin_command(
  request jsonb,
  actor_id uuid,
  command_name text,
  domain_name text,
  aggregate_scope text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_receipt_id uuid;
  v_existing_receipt atlas_core.command_receipts%rowtype;
  v_hash text;
  v_scope_key text;
begin
  v_hash := atlas_core.pa_05b_request_hash(request);
  v_scope_key := actor_id::text || ':' || aggregate_scope;

  select cr.command_receipt_id
  into v_receipt_id
  from atlas_core.command_receipts cr
  where cr.command_id = atlas_core.pa_05b_safe_uuid(request ->> 'command_id');

  if found then
    select cr.*
    into v_existing_receipt
    from atlas_core.command_receipts cr
    where cr.command_receipt_id = v_receipt_id
    for update;

    if v_existing_receipt.scope_key <> v_scope_key
       or v_existing_receipt.command_name <> pa_05b_begin_command.command_name
       or v_existing_receipt.idempotency_key <> request ->> 'idempotency_key' then
      return pg_catalog.jsonb_build_object(
        'status', 'ERROR',
        'response', atlas_core.pa_05b_command_error(
          request,
          'IDEMPOTENCY_CONFLICT',
          'The command identifier is already used by a different request.',
          domain_name,
          command_name
        )
      );
    end if;
  else
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
      pa_05b_begin_command.command_name,
      v_scope_key,
      request ->> 'idempotency_key',
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
      pa_05b_begin_command.actor_id,
      atlas_core.pa_05b_safe_bigint(request ->> 'expected_version'),
      v_hash,
      'IN_PROGRESS'
    )
    on conflict on constraint command_receipts_idempotency_key do nothing
    returning command_receipt_id into v_receipt_id;

    if v_receipt_id is not null then
      return pg_catalog.jsonb_build_object('status', 'NEW', 'receipt_id', v_receipt_id);
    end if;

    select cr.*
    into v_existing_receipt
    from atlas_core.command_receipts cr
    where cr.scope_key = v_scope_key
      and cr.command_name = pa_05b_begin_command.command_name
      and cr.idempotency_key = request ->> 'idempotency_key'
    for update;
  end if;

  if v_existing_receipt.request_hash <> v_hash then
    return pg_catalog.jsonb_build_object(
      'status', 'ERROR',
      'response', atlas_core.pa_05b_command_error(
        request,
        'IDEMPOTENCY_CONFLICT',
        'The idempotency key was already used with a different request.',
        domain_name,
        command_name
      )
    );
  end if;

  if v_existing_receipt.outcome in ('COMPLETED', 'FAILED_NON_RETRYABLE') then
    return pg_catalog.jsonb_build_object(
      'status', 'REPLAY',
      'receipt_id', v_existing_receipt.command_receipt_id,
      'response', v_existing_receipt.response_payload
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'status', 'ERROR',
    'response', atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The same command is still being processed. Retry the exact request.',
      domain_name,
      command_name,
      true
    )
  );
exception
  when unique_violation then
    return pg_catalog.jsonb_build_object(
      'status', 'ERROR',
      'response', atlas_core.pa_05b_command_error(
        request,
        'IDEMPOTENCY_CONFLICT',
        'The command identity conflicts with another request.',
        domain_name,
        command_name
      )
    );
end;
$$;

create or replace function atlas_core.pa_05b_finish_command(
  p_command_receipt_id uuid,
  p_response_payload jsonb,
  p_succeeded boolean
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
begin
  update atlas_core.command_receipts cr
  set outcome = case when p_succeeded then 'COMPLETED' else 'FAILED_NON_RETRYABLE' end,
      response_payload = p_response_payload,
      error_code = case when p_succeeded then null else p_response_payload ->> 'error_code' end,
      completed_at = pg_catalog.transaction_timestamp()
  where cr.command_receipt_id = p_command_receipt_id
    and cr.outcome = 'IN_PROGRESS';

  return p_response_payload;
end;
$$;

create or replace function atlas_api.record_supplier_receiving_evidence(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'record_supplier_receiving_evidence';
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_error jsonb;
  v_payload jsonb := request -> 'payload';
  v_purchase_order_line_revision_id uuid;
  v_requested_supplier_id uuid;
  v_requested_ingredient_id uuid;
  v_requested_unit_id uuid;
  v_evidence_quantity numeric;
  v_occurred_at timestamptz;
  v_evidence_reference text;
  v_purchase_order_id uuid;
  v_purchase_order_version bigint;
  v_purchase_order_status text;
  v_purchase_order_revision_status text;
  v_committed_supplier_id uuid;
  v_allocation_supplier_id uuid;
  v_committed_ingredient_id uuid;
  v_committed_unit_id uuid;
  v_dispatch_requirement_id uuid;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_evidence_id uuid;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05b_validate_command_request(request, 'EVIDENCE', v_command_name);
  if v_error is not null then
    return v_error;
  end if;

  v_purchase_order_line_revision_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'purchase_order_line_revision_id'
  );
  v_requested_supplier_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'supplier_id');
  v_requested_ingredient_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_id');
  v_requested_unit_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'unit_id');
  v_evidence_quantity := atlas_core.pa_05b_safe_numeric(v_payload ->> 'evidence_quantity');
  v_occurred_at := atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'occurred_at');
  v_evidence_reference := pg_catalog.btrim(coalesce(v_payload ->> 'evidence_reference', ''));

  if v_purchase_order_line_revision_id is null
     or v_requested_supplier_id is null
     or v_requested_ingredient_id is null
     or v_requested_unit_id is null
     or v_evidence_quantity is null
     or v_occurred_at is null
     or v_evidence_reference = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The supplier evidence payload is incomplete or invalid.',
      'EVIDENCE',
      v_command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload',
          'message',
          'PO line, supplier, ingredient, unit, quantity, evidence reference, and occurred_at are required.'
        )
      )
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'EVIDENCE', v_command_name);
  if v_actor_context ? 'error' then
    return v_actor_context -> 'error';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select
    po.purchase_order_id,
    po.version,
    po.purchase_order_status,
    por.revision_status,
    po.supplier_id,
    falr.supplier_id,
    polr.ingredient_id,
    polr.unit_id,
    dr.dispatch_requirement_id,
    dr.customer_id,
    dr.delivery_location_id
  into
    v_purchase_order_id,
    v_purchase_order_version,
    v_purchase_order_status,
    v_purchase_order_revision_status,
    v_committed_supplier_id,
    v_allocation_supplier_id,
    v_committed_ingredient_id,
    v_committed_unit_id,
    v_dispatch_requirement_id,
    v_customer_id,
    v_delivery_location_id
  from atlas_procurement.purchase_order_line_revisions polr
  join atlas_procurement.purchase_order_revisions por
    on por.purchase_order_revision_id = polr.purchase_order_revision_id
  join atlas_procurement.purchase_orders po
    on po.purchase_order_id = por.purchase_order_id
  join atlas_procurement.fulfilment_allocation_line_revisions falr
    on falr.fulfilment_allocation_line_revision_id = polr.fulfilment_allocation_line_revision_id
  join atlas_procurement.fulfilment_allocation_revisions far
    on far.fulfilment_allocation_revision_id = falr.fulfilment_allocation_revision_id
  join atlas_procurement.fulfilment_allocations fa
    on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = fa.dispatch_requirement_id
  where polr.purchase_order_line_revision_id = v_purchase_order_line_revision_id;

  if not found then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The released supplier commitment could not be validated.',
      'EVIDENCE',
      v_command_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_purchase_order_line_revision_id)
    );
  end if;

  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request,
    v_actor_id,
    'supplier_receiving_evidence.record',
    'EVIDENCE',
    v_command_name,
    v_customer_id,
    v_delivery_location_id,
    null
  );
  if v_authorization_error is not null then
    return v_authorization_error;
  end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_command_name,
    'EVIDENCE',
    'purchase-order-line:' || v_purchase_order_line_revision_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return v_begin -> 'response';
  end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1
  from atlas_admin.suppliers s
  where s.supplier_id in (v_committed_supplier_id, v_requested_supplier_id)
  order by s.supplier_id
  for key share;
  perform 1
  from atlas_admin.ingredients i
  where i.ingredient_id in (v_committed_ingredient_id, v_requested_ingredient_id)
  order by i.ingredient_id
  for key share;
  perform 1
  from atlas_admin.units u
  where u.unit_id in (v_committed_unit_id, v_requested_unit_id)
  order by u.unit_id
  for key share;
  perform 1
  from atlas_admin.delivery_locations dl
  where dl.delivery_location_id = v_delivery_location_id
  for key share;
  perform 1
  from atlas_planning.dispatch_requirements dr
  where dr.dispatch_requirement_id = v_dispatch_requirement_id
  for key share;
  perform 1
  from atlas_procurement.purchase_orders po
  where po.purchase_order_id = v_purchase_order_id
  for update;
  perform 1
  from atlas_procurement.purchase_order_line_revisions polr
  where polr.purchase_order_line_revision_id = v_purchase_order_line_revision_id
  for key share;

  select
    po.version,
    po.purchase_order_status,
    por.revision_status,
    po.supplier_id,
    falr.supplier_id,
    polr.ingredient_id,
    polr.unit_id
  into
    v_purchase_order_version,
    v_purchase_order_status,
    v_purchase_order_revision_status,
    v_committed_supplier_id,
    v_allocation_supplier_id,
    v_committed_ingredient_id,
    v_committed_unit_id
  from atlas_procurement.purchase_order_line_revisions polr
  join atlas_procurement.purchase_order_revisions por
    on por.purchase_order_revision_id = polr.purchase_order_revision_id
  join atlas_procurement.purchase_orders po
    on po.purchase_order_id = por.purchase_order_id
  join atlas_procurement.fulfilment_allocation_line_revisions falr
    on falr.fulfilment_allocation_line_revision_id = polr.fulfilment_allocation_line_revision_id
  where polr.purchase_order_line_revision_id = v_purchase_order_line_revision_id;

  if v_purchase_order_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'STALE_VERSION',
      'The purchase order changed. Refresh and review before recording evidence.',
      'EVIDENCE',
      v_command_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_purchase_order_id),
      v_purchase_order_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_purchase_order_status not in ('RELEASED_TO_SUPPLIER', 'SUPPLIER_CONFIRMED')
     or v_purchase_order_revision_status not in ('RELEASED_TO_SUPPLIER', 'SUPPLIER_CONFIRMED') then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Supplier evidence requires a released purchase-order line.',
      'EVIDENCE',
      v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_requested_supplier_id <> v_committed_supplier_id
     or v_requested_supplier_id <> v_allocation_supplier_id
     or v_requested_ingredient_id <> v_committed_ingredient_id
     or v_requested_unit_id <> v_committed_unit_id then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'Supplier, ingredient, and unit must match the released supplier commitment.',
      'EVIDENCE',
      v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_evidence_quantity <= 0 or v_occurred_at > pg_catalog.transaction_timestamp() then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Evidence quantity must be positive and occurred_at must not be in the future.',
      'EVIDENCE',
      v_command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.evidence_quantity', 'message', 'Use a positive quantity.'),
        pg_catalog.jsonb_build_object('field', 'payload.occurred_at', 'message', 'Use a valid non-future time.')
      )
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_evidence.supplier_receiving_evidence sre
    where sre.supplier_id = v_requested_supplier_id
      and sre.evidence_reference = v_evidence_reference
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'The supplier evidence reference is already recorded.',
      'EVIDENCE',
      v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  insert into atlas_evidence.supplier_receiving_evidence (
    supplier_id,
    purchase_order_line_revision_id,
    ingredient_id,
    evidence_reference,
    evidence_quantity,
    unit_id,
    reason_note,
    occurred_at,
    recorded_by_actor_id,
    command_id,
    correlation_id
  ) values (
    v_requested_supplier_id,
    v_purchase_order_line_revision_id,
    v_requested_ingredient_id,
    v_evidence_reference,
    v_evidence_quantity,
    v_requested_unit_id,
    request ->> 'reason_note',
    v_occurred_at,
    v_actor_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id')
  )
  returning supplier_receiving_evidence_id into v_evidence_id;

  insert into atlas_audit.domain_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    occurred_at,
    payload_summary
  ) values (
    'SupplierReceivingEvidenceRecorded',
    'EVIDENCE',
    'SupplierReceivingEvidence',
    v_evidence_id,
    v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'purchase_order_line_revision_id', v_purchase_order_line_revision_id,
      'quantity', v_evidence_quantity,
      'unit_id', v_requested_unit_id
    )
  )
  returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    reason_code,
    reason_note,
    after_summary,
    source_interface,
    occurred_at
  ) values (
    'SupplierReceivingEvidenceRecorded',
    'EVIDENCE',
    'SupplierReceivingEvidence',
    v_evidence_id,
    v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,
    request ->> 'reason_code',
    request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status', 'VALID', 'quantity', v_evidence_quantity),
    'atlas_api',
    pg_catalog.transaction_timestamp()
  )
  returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'supplier_receiving_evidence_id', v_evidence_id,
      'purchase_order_id', v_purchase_order_id
    ),
    'new_versions', pg_catalog.jsonb_build_object('purchase_order_version', v_purchase_order_version),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Supplier receiving evidence recorded.',
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );

  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'EVIDENCE',
      v_command_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'Supplier evidence could not be recorded safely.',
      'EVIDENCE',
      v_command_name
    );
end;
$$;

create or replace function atlas_api.apply_supplier_evidence_to_allocation(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'apply_supplier_evidence_to_allocation';
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_error jsonb;
  v_payload jsonb := request -> 'payload';
  v_evidence_id uuid;
  v_allocation_line_revision_id uuid;
  v_requested_unit_id uuid;
  v_applied_quantity numeric;
  v_occurred_at timestamptz;
  v_evidence_status text;
  v_evidence_quantity numeric;
  v_evidence_unit_id uuid;
  v_evidence_ingredient_id uuid;
  v_evidence_supplier_id uuid;
  v_allocation_id uuid;
  v_allocation_version bigint;
  v_allocation_quantity numeric;
  v_allocation_unit_id uuid;
  v_allocation_ingredient_id uuid;
  v_allocation_supplier_id uuid;
  v_dispatch_requirement_id uuid;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_existing_evidence_applied numeric;
  v_existing_allocation_applied numeric;
  v_application_id uuid;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05b_validate_command_request(request, 'EVIDENCE', v_command_name);
  if v_error is not null then
    return v_error;
  end if;

  v_evidence_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'supplier_receiving_evidence_id');
  v_allocation_line_revision_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'fulfilment_allocation_line_revision_id'
  );
  v_requested_unit_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'unit_id');
  v_applied_quantity := atlas_core.pa_05b_safe_numeric(v_payload ->> 'applied_quantity');
  v_occurred_at := atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'occurred_at');

  if v_evidence_id is null
     or v_allocation_line_revision_id is null
     or v_requested_unit_id is null
     or v_applied_quantity is null
     or v_occurred_at is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The evidence application payload is incomplete or invalid.',
      'EVIDENCE',
      v_command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Evidence, allocation line, unit, quantity, and occurred_at are required.')
      )
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'EVIDENCE', v_command_name);
  if v_actor_context ? 'error' then
    return v_actor_context -> 'error';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select
    sre.evidence_status,
    sre.evidence_quantity,
    sre.unit_id,
    sre.ingredient_id,
    sre.supplier_id,
    fa.fulfilment_allocation_id,
    fa.version,
    falr.allocated_quantity,
    falr.unit_id,
    drlr.ingredient_id,
    falr.supplier_id,
    dr.dispatch_requirement_id,
    dr.customer_id,
    dr.delivery_location_id
  into
    v_evidence_status,
    v_evidence_quantity,
    v_evidence_unit_id,
    v_evidence_ingredient_id,
    v_evidence_supplier_id,
    v_allocation_id,
    v_allocation_version,
    v_allocation_quantity,
    v_allocation_unit_id,
    v_allocation_ingredient_id,
    v_allocation_supplier_id,
    v_dispatch_requirement_id,
    v_customer_id,
    v_delivery_location_id
  from atlas_evidence.supplier_receiving_evidence sre
  cross join atlas_procurement.fulfilment_allocation_line_revisions falr
  join atlas_procurement.fulfilment_allocation_revisions far
    on far.fulfilment_allocation_revision_id = falr.fulfilment_allocation_revision_id
  join atlas_procurement.fulfilment_allocations fa
    on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
  join atlas_planning.dispatch_requirement_line_revisions drlr
    on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = fa.dispatch_requirement_id
  where sre.supplier_receiving_evidence_id = v_evidence_id
    and falr.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id;

  if not found then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The evidence and allocation line could not be validated.',
      'EVIDENCE',
      v_command_name
    );
  end if;

  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request,
    v_actor_id,
    'supplier_evidence_application.apply',
    'EVIDENCE',
    v_command_name,
    v_customer_id,
    v_delivery_location_id,
    null
  );
  if v_authorization_error is not null then
    return v_authorization_error;
  end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_command_name,
    'EVIDENCE',
    'allocation-line:' || v_allocation_line_revision_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return v_begin -> 'response';
  end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1 from atlas_admin.units u
  where u.unit_id in (v_evidence_unit_id, v_allocation_unit_id, v_requested_unit_id)
  order by u.unit_id for key share;
  perform 1 from atlas_admin.ingredients i
  where i.ingredient_id in (v_evidence_ingredient_id, v_allocation_ingredient_id)
  order by i.ingredient_id for key share;
  perform 1 from atlas_planning.dispatch_requirements dr
  where dr.dispatch_requirement_id = v_dispatch_requirement_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocations fa
  where fa.fulfilment_allocation_id = v_allocation_id for update;
  perform 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
  where falr.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id for update;
  perform 1 from atlas_evidence.supplier_receiving_evidence sre
  where sre.supplier_receiving_evidence_id = v_evidence_id for update;
  perform 1 from atlas_evidence.evidence_applications ea
  where ea.supplier_receiving_evidence_id = v_evidence_id
     or ea.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id
  order by ea.evidence_application_id for update;

  select
    sre.evidence_status,
    sre.evidence_quantity,
    sre.unit_id,
    sre.ingredient_id,
    sre.supplier_id,
    fa.version,
    falr.allocated_quantity,
    falr.unit_id,
    drlr.ingredient_id
    , falr.supplier_id
  into
    v_evidence_status,
    v_evidence_quantity,
    v_evidence_unit_id,
    v_evidence_ingredient_id,
    v_evidence_supplier_id,
    v_allocation_version,
    v_allocation_quantity,
    v_allocation_unit_id,
    v_allocation_ingredient_id,
    v_allocation_supplier_id
  from atlas_evidence.supplier_receiving_evidence sre
  cross join atlas_procurement.fulfilment_allocation_line_revisions falr
  join atlas_procurement.fulfilment_allocation_revisions far
    on far.fulfilment_allocation_revision_id = falr.fulfilment_allocation_revision_id
  join atlas_procurement.fulfilment_allocations fa
    on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
  join atlas_planning.dispatch_requirement_line_revisions drlr
    on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
  where sre.supplier_receiving_evidence_id = v_evidence_id
    and falr.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id;

  if v_allocation_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'STALE_VERSION',
      'The fulfilment allocation changed. Refresh and review before applying evidence.',
      'EVIDENCE',
      v_command_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_allocation_id),
      v_allocation_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_evidence_status <> 'VALID' then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'EVIDENCE_VOIDED',
      'Only current valid supplier evidence may be applied.',
      'EVIDENCE',
      v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_applied_quantity <= 0 or v_occurred_at > pg_catalog.transaction_timestamp() then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Applied quantity must be positive and occurred_at must not be in the future.',
      'EVIDENCE',
      v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_evidence_ingredient_id <> v_allocation_ingredient_id
     or v_evidence_supplier_id <> v_allocation_supplier_id
     or v_evidence_unit_id <> v_allocation_unit_id
     or v_requested_unit_id <> v_evidence_unit_id then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'Evidence and allocation ingredient/unit lineage must match exactly.',
      'EVIDENCE',
      v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_evidence.evidence_applications ea
    where ea.supplier_receiving_evidence_id = v_evidence_id
      and ea.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id
      and ea.application_status = 'VALID'
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'A current evidence application already links this evidence and allocation line.',
      'EVIDENCE',
      v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select coalesce(pg_catalog.sum(ea.applied_quantity), 0)
  into v_existing_evidence_applied
  from atlas_evidence.evidence_applications ea
  where ea.supplier_receiving_evidence_id = v_evidence_id
    and ea.application_status = 'VALID';

  select coalesce(pg_catalog.sum(ea.applied_quantity), 0)
  into v_existing_allocation_applied
  from atlas_evidence.evidence_applications ea
  where ea.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id
    and ea.application_status = 'VALID';

  if v_existing_evidence_applied + v_applied_quantity > v_evidence_quantity then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'EVIDENCE_OVER_APPLIED',
      'The application would exceed the current supplier evidence quantity.',
      'EVIDENCE',
      v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_existing_allocation_applied + v_applied_quantity > v_allocation_quantity then
    v_error := atlas_core.pa_05b_command_error(
      request,
      'EVIDENCE_OVER_APPLIED',
      'The application would exceed the allocation-line quantity.',
      'EVIDENCE',
      v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  insert into atlas_evidence.evidence_applications (
    supplier_receiving_evidence_id,
    fulfilment_allocation_line_revision_id,
    applied_quantity,
    unit_id,
    reason_note,
    occurred_at,
    recorded_by_actor_id,
    command_id,
    correlation_id
  ) values (
    v_evidence_id,
    v_allocation_line_revision_id,
    v_applied_quantity,
    v_requested_unit_id,
    request ->> 'reason_note',
    v_occurred_at,
    v_actor_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id')
  )
  returning evidence_application_id into v_application_id;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id, command_receipt_id,
    command_id, correlation_id, actor_id, occurred_at, payload_summary
  ) values (
    'EvidenceAppliedToAllocation', 'EVIDENCE', 'EvidenceApplication', v_application_id, v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id, pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'supplier_receiving_evidence_id', v_evidence_id,
      'fulfilment_allocation_line_revision_id', v_allocation_line_revision_id,
      'quantity', v_applied_quantity,
      'unit_id', v_requested_unit_id
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id, command_receipt_id,
    command_id, correlation_id, actor_id, reason_code, reason_note,
    after_summary, source_interface, occurred_at
  ) values (
    'EvidenceAppliedToAllocation', 'EVIDENCE', 'EvidenceApplication', v_application_id, v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id, request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status', 'VALID', 'quantity', v_applied_quantity),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'evidence_application_id', v_application_id,
      'supplier_receiving_evidence_id', v_evidence_id,
      'fulfilment_allocation_id', v_allocation_id
    ),
    'new_versions', pg_catalog.jsonb_build_object('fulfilment_allocation_version', v_allocation_version),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Supplier evidence applied to the allocation line.',
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );

  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'EVIDENCE', v_command_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'Supplier evidence could not be applied safely.',
      'EVIDENCE', v_command_name
    );
end;
$$;

create or replace function atlas_api.confirm_dispatch_load(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'confirm_dispatch_load';
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_error jsonb;
  v_payload jsonb := request -> 'payload';
  v_trip_id uuid;
  v_stop_id uuid;
  v_requirement_revision_id uuid;
  v_allocation_revision_id uuid;
  v_requirement_line_revision_id uuid;
  v_allocation_line_revision_id uuid;
  v_evidence_application_id uuid;
  v_requested_unit_id uuid;
  v_loaded_quantity numeric;
  v_loaded_at timestamptz;
  v_plan_id uuid;
  v_trip_status text;
  v_trip_version bigint;
  v_stop_status text;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_dispatch_requirement_id uuid;
  v_allocation_id uuid;
  v_ingredient_id uuid;
  v_allocation_unit_id uuid;
  v_allocation_quantity numeric;
  v_application_quantity numeric;
  v_application_unit_id uuid;
  v_application_status text;
  v_evidence_status text;
  v_evidence_ingredient_id uuid;
  v_evidence_unit_id uuid;
  v_existing_application_load numeric;
  v_existing_allocation_load numeric;
  v_load_id uuid;
  v_load_line_id uuid;
  v_new_trip_version bigint;
  v_new_stop_version bigint;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05b_validate_command_request(request, 'DISPATCH', v_command_name);
  if v_error is not null then
    return v_error;
  end if;

  v_trip_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_trip_id');
  v_stop_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_stop_id');
  v_requirement_revision_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'dispatch_requirement_revision_id'
  );
  v_allocation_revision_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'fulfilment_allocation_revision_id'
  );
  v_requirement_line_revision_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'dispatch_requirement_line_revision_id'
  );
  v_allocation_line_revision_id := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'fulfilment_allocation_line_revision_id'
  );
  v_evidence_application_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'evidence_application_id');
  v_requested_unit_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'unit_id');
  v_loaded_quantity := atlas_core.pa_05b_safe_numeric(v_payload ->> 'loaded_quantity');
  v_loaded_at := atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'loaded_at');

  if v_trip_id is null
     or v_stop_id is null
     or v_requirement_revision_id is null
     or v_allocation_revision_id is null
     or v_requirement_line_revision_id is null
     or v_allocation_line_revision_id is null
     or v_evidence_application_id is null
     or v_requested_unit_id is null
     or v_loaded_quantity is null
     or v_loaded_at is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The dispatch load payload is incomplete or invalid.',
      'DISPATCH',
      v_command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Trip, stop, exact revisions, evidence application, unit, quantity, and loaded_at are required.')
      )
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'DISPATCH', v_command_name);
  if v_actor_context ? 'error' then
    return v_actor_context -> 'error';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select
    dt.dispatch_plan_id,
    dt.trip_status,
    dt.version,
    ds.stop_status,
    ds.customer_id,
    ds.delivery_location_id,
    dr.dispatch_requirement_id,
    fa.fulfilment_allocation_id,
    drlr.ingredient_id,
    falr.unit_id,
    falr.allocated_quantity,
    ea.applied_quantity,
    ea.unit_id,
    ea.application_status,
    sre.evidence_status,
    sre.ingredient_id,
    sre.unit_id
  into
    v_plan_id,
    v_trip_status,
    v_trip_version,
    v_stop_status,
    v_customer_id,
    v_delivery_location_id,
    v_dispatch_requirement_id,
    v_allocation_id,
    v_ingredient_id,
    v_allocation_unit_id,
    v_allocation_quantity,
    v_application_quantity,
    v_application_unit_id,
    v_application_status,
    v_evidence_status,
    v_evidence_ingredient_id,
    v_evidence_unit_id
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_stops ds
    on ds.dispatch_trip_id = dt.dispatch_trip_id
  join atlas_dispatch.dispatch_plan_requirements dpr
    on dpr.dispatch_plan_id = dt.dispatch_plan_id
  join atlas_planning.dispatch_requirement_revisions drr
    on drr.dispatch_requirement_revision_id = dpr.dispatch_requirement_revision_id
  join atlas_planning.dispatch_requirements dr
    on dr.dispatch_requirement_id = drr.dispatch_requirement_id
  join atlas_planning.dispatch_requirement_line_revisions drlr
    on drlr.dispatch_requirement_revision_id = drr.dispatch_requirement_revision_id
  join atlas_procurement.fulfilment_allocation_revisions far
    on far.fulfilment_allocation_revision_id = dpr.fulfilment_allocation_revision_id
  join atlas_procurement.fulfilment_allocations fa
    on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
  join atlas_procurement.fulfilment_allocation_line_revisions falr
    on falr.fulfilment_allocation_revision_id = far.fulfilment_allocation_revision_id
    and falr.dispatch_requirement_line_revision_id = drlr.dispatch_requirement_line_revision_id
  join atlas_evidence.evidence_applications ea
    on ea.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
  join atlas_evidence.supplier_receiving_evidence sre
    on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
  where dt.dispatch_trip_id = v_trip_id
    and ds.dispatch_stop_id = v_stop_id
    and ds.dispatch_requirement_revision_id = v_requirement_revision_id
    and dpr.dispatch_requirement_revision_id = v_requirement_revision_id
    and dpr.fulfilment_allocation_revision_id = v_allocation_revision_id
    and drlr.dispatch_requirement_line_revision_id = v_requirement_line_revision_id
    and falr.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id
    and ea.evidence_application_id = v_evidence_application_id;

  if not found then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The trip, stop, allocation, and evidence lineage could not be validated.',
      'DISPATCH',
      v_command_name
    );
  end if;

  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request,
    v_actor_id,
    'dispatch_load.confirm',
    'DISPATCH',
    v_command_name,
    v_customer_id,
    v_delivery_location_id,
    v_trip_id
  );
  if v_authorization_error is not null then
    return v_authorization_error;
  end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_command_name,
    'DISPATCH',
    'trip:' || v_trip_id::text || ':allocation-line:' || v_allocation_line_revision_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return v_begin -> 'response';
  end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1 from atlas_admin.ingredients i
  where i.ingredient_id in (v_ingredient_id, v_evidence_ingredient_id)
  order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
  where u.unit_id in (v_allocation_unit_id, v_application_unit_id, v_evidence_unit_id, v_requested_unit_id)
  order by u.unit_id for key share;
  perform 1 from atlas_admin.delivery_locations dl
  where dl.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_planning.dispatch_requirements dr
  where dr.dispatch_requirement_id = v_dispatch_requirement_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_revisions drr
  where drr.dispatch_requirement_revision_id = v_requirement_revision_id for key share;
  perform 1 from atlas_planning.dispatch_requirement_line_revisions drlr
  where drlr.dispatch_requirement_line_revision_id = v_requirement_line_revision_id for key share;
  perform 1 from atlas_procurement.fulfilment_allocations fa
  where fa.fulfilment_allocation_id = v_allocation_id for update;
  perform 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
  where falr.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id for update;
  perform 1 from atlas_evidence.supplier_receiving_evidence sre
  where sre.supplier_receiving_evidence_id = (
    select ea.supplier_receiving_evidence_id
    from atlas_evidence.evidence_applications ea
    where ea.evidence_application_id = v_evidence_application_id
  ) for update;
  perform 1 from atlas_evidence.evidence_applications ea
  where ea.evidence_application_id = v_evidence_application_id for update;
  perform 1 from atlas_dispatch.dispatch_load_line_applications dlla
  where dlla.evidence_application_id = v_evidence_application_id
  order by dlla.dispatch_load_line_application_id for update;
  perform 1 from atlas_dispatch.dispatch_plans dp
  where dp.dispatch_plan_id = v_plan_id for key share;
  perform 1 from atlas_dispatch.dispatch_trips dt
  where dt.dispatch_trip_id = v_trip_id for update;
  perform 1 from atlas_dispatch.dispatch_stops ds
  where ds.dispatch_stop_id = v_stop_id for update;
  perform 1 from atlas_dispatch.dispatch_loads dl
  where dl.dispatch_trip_id = v_trip_id
  order by dl.dispatch_load_id for update;

  select dt.trip_status, dt.version, ds.stop_status
  into v_trip_status, v_trip_version, v_stop_status
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_stops ds on ds.dispatch_trip_id = dt.dispatch_trip_id
  where dt.dispatch_trip_id = v_trip_id and ds.dispatch_stop_id = v_stop_id;

  select
    falr.allocated_quantity,
    falr.unit_id,
    drlr.ingredient_id,
    ea.applied_quantity,
    ea.unit_id,
    ea.application_status,
    sre.evidence_status,
    sre.ingredient_id,
    sre.unit_id
  into
    v_allocation_quantity,
    v_allocation_unit_id,
    v_ingredient_id,
    v_application_quantity,
    v_application_unit_id,
    v_application_status,
    v_evidence_status,
    v_evidence_ingredient_id,
    v_evidence_unit_id
  from atlas_procurement.fulfilment_allocation_line_revisions falr
  join atlas_planning.dispatch_requirement_line_revisions drlr
    on drlr.dispatch_requirement_line_revision_id = falr.dispatch_requirement_line_revision_id
  join atlas_evidence.evidence_applications ea
    on ea.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
  join atlas_evidence.supplier_receiving_evidence sre
    on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
  where falr.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id
    and ea.evidence_application_id = v_evidence_application_id;

  if v_trip_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION',
      'The dispatch trip changed. Refresh and review before confirming the load.',
      'DISPATCH', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_trip_id), v_trip_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_trip_status not in ('ASSIGNED', 'LOADED') or v_stop_status not in ('PENDING', 'LOADED') then
    v_error := atlas_core.pa_05b_command_error(
      request, 'TRIP_NOT_READY',
      'The trip and stop are not eligible for load confirmation.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_loaded_quantity <= 0 or v_loaded_at > pg_catalog.transaction_timestamp() then
    v_error := atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'Loaded quantity must be positive and loaded_at must not be in the future.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_application_status <> 'VALID'
     or v_evidence_status <> 'VALID'
     or v_requested_unit_id <> v_allocation_unit_id
     or v_requested_unit_id <> v_application_unit_id
     or v_requested_unit_id <> v_evidence_unit_id
     or v_ingredient_id <> v_evidence_ingredient_id then
    v_error := atlas_core.pa_05b_command_error(
      request, 'EVIDENCE_INSUFFICIENT',
      'The requested load is not supported by current matching evidence.',
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
      'A current load already exists for this trip and allocation revision.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select coalesce(pg_catalog.sum(dlla.applied_to_load_quantity), 0)
  into v_existing_application_load
  from atlas_dispatch.dispatch_load_line_applications dlla
  join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_line_id = dlla.dispatch_load_line_id
  join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
  where dlla.evidence_application_id = v_evidence_application_id
    and dlla.application_status = 'VALID'
    and dll.line_status = 'CONFIRMED'
    and dl.load_status = 'CONFIRMED';

  select coalesce(pg_catalog.sum(dll.loaded_quantity), 0)
  into v_existing_allocation_load
  from atlas_dispatch.dispatch_load_lines dll
  join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
  where dll.fulfilment_allocation_line_revision_id = v_allocation_line_revision_id
    and dll.line_status = 'CONFIRMED'
    and dl.load_status = 'CONFIRMED';

  if v_existing_application_load + v_loaded_quantity > v_application_quantity
     or v_existing_allocation_load + v_loaded_quantity > v_allocation_quantity then
    v_error := atlas_core.pa_05b_command_error(
      request, 'EVIDENCE_INSUFFICIENT',
      'The requested load would exceed valid applied evidence or the allocation quantity.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  insert into atlas_dispatch.dispatch_loads (
    dispatch_trip_id,
    dispatch_requirement_revision_id,
    fulfilment_allocation_revision_id,
    load_status,
    loaded_by_actor_id,
    loaded_at
  ) values (
    v_trip_id,
    v_requirement_revision_id,
    v_allocation_revision_id,
    'CONFIRMED',
    v_actor_id,
    v_loaded_at
  ) returning dispatch_load_id into v_load_id;

  insert into atlas_dispatch.dispatch_load_lines (
    dispatch_load_id,
    dispatch_stop_id,
    dispatch_requirement_line_revision_id,
    fulfilment_allocation_line_revision_id,
    ingredient_id,
    loaded_quantity,
    unit_id,
    command_id
  ) values (
    v_load_id,
    v_stop_id,
    v_requirement_line_revision_id,
    v_allocation_line_revision_id,
    v_ingredient_id,
    v_loaded_quantity,
    v_requested_unit_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
  ) returning dispatch_load_line_id into v_load_line_id;

  insert into atlas_dispatch.dispatch_load_line_applications (
    dispatch_load_line_id,
    evidence_application_id,
    applied_to_load_quantity,
    unit_id
  ) values (
    v_load_line_id,
    v_evidence_application_id,
    v_loaded_quantity,
    v_requested_unit_id
  );

  update atlas_dispatch.dispatch_trips dt
  set trip_status = 'LOADED',
      version = dt.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where dt.dispatch_trip_id = v_trip_id
  returning version into v_new_trip_version;

  update atlas_dispatch.dispatch_stops ds
  set stop_status = 'LOADED',
      version = ds.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ds.dispatch_stop_id = v_stop_id
  returning version into v_new_stop_version;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at, payload_summary
  ) values (
    'DispatchLoadConfirmed', 'DISPATCH', 'DispatchLoad', v_load_id, 1,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'dispatch_load_line_id', v_load_line_id,
      'evidence_application_id', v_evidence_application_id,
      'quantity', v_loaded_quantity,
      'unit_id', v_requested_unit_id
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version_after, command_receipt_id, command_id, correlation_id,
    actor_id, reason_code, reason_note, after_summary, source_interface, occurred_at
  ) values (
    'DispatchLoadConfirmed', 'DISPATCH', 'DispatchLoad', v_load_id, 1,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status', 'CONFIRMED', 'quantity', v_loaded_quantity),
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
      'dispatch_load_line_id', v_load_line_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'dispatch_trip_version', v_new_trip_version,
      'dispatch_stop_version', v_new_stop_version,
      'dispatch_load_version', 1
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Dispatch load confirmed against current supplier evidence.',
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
      'The dispatch load could not be confirmed safely.',
      'DISPATCH', v_command_name
    );
end;
$$;

create or replace function atlas_api.record_dispatch_departure(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'record_dispatch_departure';
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_error jsonb;
  v_payload jsonb := request -> 'payload';
  v_trip_id uuid;
  v_departed_at timestamptz;
  v_plan_id uuid;
  v_trip_status text;
  v_trip_version bigint;
  v_existing_departed_at timestamptz;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_new_trip_version bigint;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05b_validate_command_request(request, 'DISPATCH', v_command_name);
  if v_error is not null then
    return v_error;
  end if;

  v_trip_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_trip_id');
  v_departed_at := atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'departed_at');
  if v_trip_id is null or v_departed_at is null then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'The departure payload requires a valid trip and departure timestamp.',
      'DISPATCH', v_command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'dispatch_trip_id and departed_at are required.')
      )
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'DISPATCH', v_command_name);
  if v_actor_context ? 'error' then
    return v_actor_context -> 'error';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select
    dt.dispatch_plan_id,
    dt.trip_status,
    dt.version,
    dt.departed_at,
    ds.customer_id,
    ds.delivery_location_id
  into
    v_plan_id,
    v_trip_status,
    v_trip_version,
    v_existing_departed_at,
    v_customer_id,
    v_delivery_location_id
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_stops ds on ds.dispatch_trip_id = dt.dispatch_trip_id
  where dt.dispatch_trip_id = v_trip_id
  order by ds.stop_sequence
  limit 1;

  if not found then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'The dispatch trip could not be validated.',
      'DISPATCH', v_command_name
    );
  end if;

  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request,
    v_actor_id,
    'dispatch_departure.record',
    'DISPATCH',
    v_command_name,
    v_customer_id,
    v_delivery_location_id,
    v_trip_id
  );
  if v_authorization_error is not null then
    return v_authorization_error;
  end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_command_name,
    'DISPATCH',
    'trip:' || v_trip_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return v_begin -> 'response';
  end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1
  from atlas_admin.delivery_locations dl
  where dl.delivery_location_id in (
    select ds.delivery_location_id
    from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = v_trip_id
  )
  order by dl.delivery_location_id
  for key share;

  perform 1
  from atlas_planning.dispatch_requirements dr
  where dr.dispatch_requirement_id in (
    select drr.dispatch_requirement_id
    from atlas_dispatch.dispatch_loads dl
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = dl.dispatch_requirement_revision_id
    where dl.dispatch_trip_id = v_trip_id and dl.load_status = 'CONFIRMED'
  )
  order by dr.dispatch_requirement_id
  for key share;

  perform 1
  from atlas_procurement.fulfilment_allocations fa
  where fa.fulfilment_allocation_id in (
    select far.fulfilment_allocation_id
    from atlas_dispatch.dispatch_loads dl
    join atlas_procurement.fulfilment_allocation_revisions far
      on far.fulfilment_allocation_revision_id = dl.fulfilment_allocation_revision_id
    where dl.dispatch_trip_id = v_trip_id and dl.load_status = 'CONFIRMED'
  )
  order by fa.fulfilment_allocation_id
  for update;

  perform 1
  from atlas_procurement.fulfilment_allocation_line_revisions falr
  where falr.fulfilment_allocation_line_revision_id in (
    select dll.fulfilment_allocation_line_revision_id
    from atlas_dispatch.dispatch_load_lines dll
    join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
    where dl.dispatch_trip_id = v_trip_id
      and dl.load_status = 'CONFIRMED'
      and dll.line_status = 'CONFIRMED'
  )
  order by falr.fulfilment_allocation_line_revision_id
  for update;

  perform 1
  from atlas_evidence.supplier_receiving_evidence sre
  where sre.supplier_receiving_evidence_id in (
    select ea.supplier_receiving_evidence_id
    from atlas_dispatch.dispatch_load_line_applications dlla
    join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_line_id = dlla.dispatch_load_line_id
    join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
    join atlas_evidence.evidence_applications ea on ea.evidence_application_id = dlla.evidence_application_id
    where dl.dispatch_trip_id = v_trip_id
      and dl.load_status = 'CONFIRMED'
      and dll.line_status = 'CONFIRMED'
      and dlla.application_status = 'VALID'
  )
  order by sre.supplier_receiving_evidence_id
  for update;

  perform 1
  from atlas_evidence.evidence_applications ea
  where ea.evidence_application_id in (
    select dlla.evidence_application_id
    from atlas_dispatch.dispatch_load_line_applications dlla
    join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_line_id = dlla.dispatch_load_line_id
    join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
    where dl.dispatch_trip_id = v_trip_id
      and dl.load_status = 'CONFIRMED'
      and dll.line_status = 'CONFIRMED'
      and dlla.application_status = 'VALID'
  )
  order by ea.evidence_application_id
  for update;

  perform 1 from atlas_dispatch.dispatch_plans dp
  where dp.dispatch_plan_id = v_plan_id for key share;
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
    select dl.dispatch_load_id from atlas_dispatch.dispatch_loads dl where dl.dispatch_trip_id = v_trip_id
  )
  order by dll.dispatch_load_line_id for update;
  perform 1 from atlas_dispatch.dispatch_load_line_applications dlla
  where dlla.dispatch_load_line_id in (
    select dll.dispatch_load_line_id
    from atlas_dispatch.dispatch_load_lines dll
    join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
    where dl.dispatch_trip_id = v_trip_id
  )
  order by dlla.dispatch_load_line_application_id for update;

  select dt.trip_status, dt.version, dt.departed_at
  into v_trip_status, v_trip_version, v_existing_departed_at
  from atlas_dispatch.dispatch_trips dt
  where dt.dispatch_trip_id = v_trip_id;

  if v_trip_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
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
      request, 'TRIP_NOT_READY',
      'The trip is not in a departure-eligible loaded state.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_departed_at > pg_catalog.transaction_timestamp() then
    v_error := atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'Departure time must not be in the future.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_dispatch.dispatch_stops ds
    where ds.dispatch_trip_id = v_trip_id
      and (
        ds.stop_status <> 'LOADED'
        or not exists (
          select 1
          from atlas_dispatch.dispatch_loads dl
          where dl.dispatch_trip_id = v_trip_id
            and dl.dispatch_requirement_revision_id = ds.dispatch_requirement_revision_id
            and dl.load_status = 'CONFIRMED'
        )
      )
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DEPARTURE_BLOCKED',
      'Every stop must have a current confirmed load before departure.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_dispatch.dispatch_load_lines dll
    join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
    left join atlas_dispatch.dispatch_load_line_applications dlla
      on dlla.dispatch_load_line_id = dll.dispatch_load_line_id
      and dlla.application_status = 'VALID'
    left join atlas_evidence.evidence_applications ea
      on ea.evidence_application_id = dlla.evidence_application_id
      and ea.application_status = 'VALID'
    left join atlas_evidence.supplier_receiving_evidence sre
      on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
      and sre.evidence_status = 'VALID'
    where dl.dispatch_trip_id = v_trip_id
      and dl.load_status = 'CONFIRMED'
      and dll.line_status = 'CONFIRMED'
    group by dll.dispatch_load_line_id, dll.loaded_quantity
    having coalesce(
      pg_catalog.sum(
        case when ea.evidence_application_id is not null and sre.supplier_receiving_evidence_id is not null
          then dlla.applied_to_load_quantity else 0 end
      ),
      0
    ) < dll.loaded_quantity
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DEPARTURE_BLOCKED',
      'Current valid supplier evidence no longer covers every loaded quantity.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_evidence.evidence_applications ea
    join atlas_dispatch.dispatch_load_line_applications dlla
      on dlla.evidence_application_id = ea.evidence_application_id
    join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_line_id = dlla.dispatch_load_line_id
    join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
    where dl.load_status = 'CONFIRMED'
      and dll.line_status = 'CONFIRMED'
      and dlla.application_status = 'VALID'
      and ea.evidence_application_id in (
        select dlla2.evidence_application_id
        from atlas_dispatch.dispatch_load_line_applications dlla2
        join atlas_dispatch.dispatch_load_lines dll2 on dll2.dispatch_load_line_id = dlla2.dispatch_load_line_id
        join atlas_dispatch.dispatch_loads dl2 on dl2.dispatch_load_id = dll2.dispatch_load_id
        where dl2.dispatch_trip_id = v_trip_id
      )
    group by ea.evidence_application_id, ea.applied_quantity
    having pg_catalog.sum(dlla.applied_to_load_quantity) > ea.applied_quantity
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DEPARTURE_BLOCKED',
      'A loaded evidence application is over-consumed.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  update atlas_dispatch.dispatch_trips dt
  set trip_status = 'IN_TRANSIT',
      departed_at = v_departed_at,
      version = dt.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where dt.dispatch_trip_id = v_trip_id
  returning version into v_new_trip_version;

  update atlas_dispatch.dispatch_stops ds
  set stop_status = 'IN_TRANSIT',
      version = ds.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ds.dispatch_trip_id = v_trip_id and ds.stop_status = 'LOADED';

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at, payload_summary
  ) values (
    'DispatchDeparted', 'DISPATCH', 'DispatchTrip', v_trip_id, v_new_trip_version,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object('departed_at', v_departed_at)
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version_before, aggregate_version_after, command_receipt_id,
    command_id, correlation_id, actor_id, reason_code, reason_note,
    before_summary, after_summary, source_interface, occurred_at
  ) values (
    'DispatchDeparted', 'DISPATCH', 'DispatchTrip', v_trip_id,
    v_trip_version, v_new_trip_version, v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status', 'LOADED'),
    pg_catalog.jsonb_build_object('status', 'IN_TRANSIT', 'departed_at', v_departed_at),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object('dispatch_trip_id', v_trip_id),
    'new_versions', pg_catalog.jsonb_build_object('dispatch_trip_version', v_new_trip_version),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Dispatch departure recorded after evidence revalidation.',
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

create or replace function atlas_api.confirm_successful_delivery(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'confirm_successful_delivery';
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_error jsonb;
  v_payload jsonb := request -> 'payload';
  v_trip_id uuid;
  v_stop_id uuid;
  v_load_line_id uuid;
  v_requested_unit_id uuid;
  v_delivered_quantity numeric;
  v_returned_quantity numeric;
  v_exception_quantity numeric;
  v_confirmed_at timestamptz;
  v_trip_status text;
  v_trip_version bigint;
  v_departed_at timestamptz;
  v_stop_status text;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_load_id uuid;
  v_load_status text;
  v_loaded_quantity numeric;
  v_loaded_unit_id uuid;
  v_new_trip_version bigint;
  v_new_stop_version bigint;
  v_confirmation_id uuid;
  v_confirmation_line_id uuid;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05b_validate_command_request(request, 'DISPATCH', v_command_name);
  if v_error is not null then
    return v_error;
  end if;

  v_trip_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_trip_id');
  v_stop_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_stop_id');
  v_load_line_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dispatch_load_line_id');
  v_requested_unit_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'unit_id');
  v_delivered_quantity := atlas_core.pa_05b_safe_numeric(v_payload ->> 'delivered_quantity');
  v_returned_quantity := coalesce(
    atlas_core.pa_05b_safe_numeric(v_payload ->> 'returned_quantity'),
    0
  );
  v_exception_quantity := coalesce(
    atlas_core.pa_05b_safe_numeric(v_payload ->> 'exception_quantity'),
    0
  );
  v_confirmed_at := atlas_core.pa_05b_safe_timestamptz(v_payload ->> 'confirmed_at');

  if v_trip_id is null
     or v_stop_id is null
     or v_load_line_id is null
     or v_requested_unit_id is null
     or v_delivered_quantity is null
     or v_confirmed_at is null then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'The successful-delivery payload is incomplete or invalid.',
      'DISPATCH', v_command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Trip, stop, load line, quantity, unit, and confirmed_at are required.')
      )
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'DISPATCH', v_command_name);
  if v_actor_context ? 'error' then
    return v_actor_context -> 'error';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select
    dt.trip_status,
    dt.version,
    dt.departed_at,
    ds.stop_status,
    ds.customer_id,
    ds.delivery_location_id,
    dl.dispatch_load_id,
    dl.load_status,
    dll.loaded_quantity,
    dll.unit_id
  into
    v_trip_status,
    v_trip_version,
    v_departed_at,
    v_stop_status,
    v_customer_id,
    v_delivery_location_id,
    v_load_id,
    v_load_status,
    v_loaded_quantity,
    v_loaded_unit_id
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_stops ds on ds.dispatch_trip_id = dt.dispatch_trip_id
  join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_stop_id = ds.dispatch_stop_id
  join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
  where dt.dispatch_trip_id = v_trip_id
    and ds.dispatch_stop_id = v_stop_id
    and dll.dispatch_load_line_id = v_load_line_id
    and dl.dispatch_trip_id = v_trip_id;

  if not found then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'The trip, stop, and load line could not be validated.',
      'DISPATCH', v_command_name
    );
  end if;

  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request,
    v_actor_id,
    'delivery_success.confirm',
    'DISPATCH',
    v_command_name,
    v_customer_id,
    v_delivery_location_id,
    v_trip_id
  );
  if v_authorization_error is not null then
    return v_authorization_error;
  end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_command_name,
    'DISPATCH',
    'stop:' || v_stop_id::text || ':load-line:' || v_load_line_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return v_begin -> 'response';
  end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1 from atlas_admin.units u
  where u.unit_id in (v_requested_unit_id, v_loaded_unit_id)
  order by u.unit_id for key share;
  perform 1 from atlas_admin.delivery_locations dl
  where dl.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_dispatch.dispatch_trips dt
  where dt.dispatch_trip_id = v_trip_id for update;
  perform 1 from atlas_dispatch.dispatch_stops ds
  where ds.dispatch_stop_id = v_stop_id for update;
  perform 1 from atlas_dispatch.dispatch_loads dl
  where dl.dispatch_load_id = v_load_id for update;
  perform 1 from atlas_dispatch.dispatch_load_lines dll
  where dll.dispatch_load_line_id = v_load_line_id for update;
  perform 1 from atlas_dispatch.delivery_confirmations dc
  where dc.dispatch_stop_id = v_stop_id
  order by dc.delivery_confirmation_id for update;

  select
    dt.trip_status,
    dt.version,
    dt.departed_at,
    ds.stop_status,
    dl.load_status,
    dll.loaded_quantity,
    dll.unit_id
  into
    v_trip_status,
    v_trip_version,
    v_departed_at,
    v_stop_status,
    v_load_status,
    v_loaded_quantity,
    v_loaded_unit_id
  from atlas_dispatch.dispatch_trips dt
  join atlas_dispatch.dispatch_stops ds on ds.dispatch_trip_id = dt.dispatch_trip_id
  join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_stop_id = ds.dispatch_stop_id
  join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
  where dt.dispatch_trip_id = v_trip_id
    and ds.dispatch_stop_id = v_stop_id
    and dll.dispatch_load_line_id = v_load_line_id
    and dl.dispatch_trip_id = v_trip_id;

  if v_trip_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
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
     or v_stop_status <> 'IN_TRANSIT'
     or v_load_status <> 'CONFIRMED' then
    v_error := atlas_core.pa_05b_command_error(
      request, 'TRIP_NOT_READY',
      'Successful delivery may be confirmed only after departure for a current confirmed load.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_delivered_quantity <= 0
     or v_delivered_quantity > v_loaded_quantity
     or v_delivered_quantity <> v_loaded_quantity
     or v_returned_quantity <> 0
     or v_exception_quantity <> 0
     or v_requested_unit_id <> v_loaded_unit_id then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DELIVERY_RECONCILIATION_FAILED',
      'Successful delivery must exactly match the loaded quantity and unit with no return or exception quantity.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_confirmed_at < v_departed_at or v_confirmed_at > pg_catalog.transaction_timestamp() then
    v_error := atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED',
      'Delivery confirmation time must be after departure and not in the future.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1 from atlas_dispatch.delivery_confirmations dc
    where dc.dispatch_stop_id = v_stop_id and dc.confirmation_status = 'VALID'
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'A current delivery confirmation already exists for this stop.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_dispatch.dispatch_load_lines dll
    join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
    where dll.dispatch_stop_id = v_stop_id
      and dl.load_status = 'CONFIRMED'
      and dll.line_status = 'CONFIRMED'
      and dll.dispatch_load_line_id <> v_load_line_id
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'DELIVERY_RECONCILIATION_FAILED',
      'PA-05B successful delivery requires the stop to contain one confirmed load line.',
      'DISPATCH', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  insert into atlas_dispatch.delivery_confirmations (
    dispatch_stop_id,
    revision_number,
    delivery_outcome,
    confirmed_by_actor_id,
    confirmed_at,
    received_by_reference,
    notes,
    command_id,
    correlation_id
  ) values (
    v_stop_id,
    1,
    'DELIVERED',
    v_actor_id,
    v_confirmed_at,
    v_payload ->> 'received_by_reference',
    v_payload ->> 'notes',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id')
  ) returning delivery_confirmation_id into v_confirmation_id;

  insert into atlas_dispatch.delivery_confirmation_lines (
    delivery_confirmation_id,
    dispatch_load_line_id,
    delivered_quantity,
    returned_quantity,
    exception_quantity,
    unit_id
  ) values (
    v_confirmation_id,
    v_load_line_id,
    v_delivered_quantity,
    0,
    0,
    v_requested_unit_id
  ) returning delivery_confirmation_line_id into v_confirmation_line_id;

  update atlas_dispatch.dispatch_stops ds
  set stop_status = 'DELIVERED',
      version = ds.version + 1,
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
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at, payload_summary
  ) values (
    'SuccessfulDeliveryConfirmed', 'DISPATCH', 'DeliveryConfirmation', v_confirmation_id,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'dispatch_load_line_id', v_load_line_id,
      'delivered_quantity', v_delivered_quantity,
      'unit_id', v_requested_unit_id
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    command_receipt_id, command_id, correlation_id, actor_id,
    reason_code, reason_note, after_summary, source_interface, occurred_at
  ) values (
    'SuccessfulDeliveryConfirmed', 'DISPATCH', 'DeliveryConfirmation', v_confirmation_id,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('outcome', 'DELIVERED', 'quantity', v_delivered_quantity),
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
      'delivery_confirmation_line_id', v_confirmation_line_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'dispatch_trip_version', v_new_trip_version,
      'dispatch_stop_version', v_new_stop_version
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Successful delivery confirmed and reconciled to the load.',
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
      'Successful delivery could not be confirmed safely.',
      'DISPATCH', v_command_name
    );
end;
$$;

create or replace function atlas_core.pa_05b_validate_trace_request(request jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb),
      'VALIDATION_FAILED',
      'The read request must be a JSON object.',
      'REPORTING',
      'get_supplier_direct_trace'
    );
  end if;

  if request ->> 'contract_version' is distinct from 'PA-05B.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use PA-05B.v1.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'requested_by_auth_subject', 'message', 'A valid UUID is required.')
    );
  end if;
  if request -> 'payload' is null or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'A JSON object is required.')
    );
  elsif atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'wholesale_order_line_revision_id'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload.wholesale_order_line_revision_id', 'message', 'A valid UUID is required.')
    );
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The supplier-direct trace request is invalid.',
      'REPORTING',
      'get_supplier_direct_trace',
      false,
      v_errors
    );
  end if;

  return null;
end;
$$;

create or replace function atlas_api.get_supplier_direct_trace(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'get_supplier_direct_trace';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_source_revision_id uuid;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_trip_id uuid;
  v_trace jsonb;
begin
  v_error := atlas_core.pa_05b_validate_trace_request(request);
  if v_error is not null then
    return v_error;
  end if;

  v_source_revision_id := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'wholesale_order_line_revision_id'
  );

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'REPORTING', v_command_name);
  if v_actor_context ? 'error' then
    return v_actor_context -> 'error';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select t.customer_id, t.delivery_location_id, dl.dispatch_trip_id
  into v_customer_id, v_delivery_location_id, v_trip_id
  from atlas_reporting.supplier_direct_slice_trace t
  join atlas_dispatch.dispatch_load_lines dll
    on dll.dispatch_load_line_id = t.dispatch_load_line_id
  join atlas_dispatch.dispatch_loads dl
    on dl.dispatch_load_id = dll.dispatch_load_id
  where t.wholesale_order_line_revision_id = v_source_revision_id
  limit 1;

  if not found then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'No completed supplier-direct trace is available for the requested source revision.',
      'REPORTING',
      v_command_name
    );
  end if;

  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request,
    v_actor_id,
    'supplier_direct_trace.read',
    'REPORTING',
    v_command_name,
    v_customer_id,
    v_delivery_location_id,
    v_trip_id
  );
  if v_authorization_error is not null then
    return v_authorization_error;
  end if;

  select pg_catalog.jsonb_build_object(
    'public_source_references', pg_catalog.jsonb_build_object(
      'customer_order_reference', wo.customer_order_reference,
      'purchase_order_number', po.document_number,
      'trip_reference', dt.trip_reference
    ),
    'opaque_ids', pg_catalog.jsonb_build_object(
      'wholesale_order_id', t.wholesale_order_id,
      'wholesale_order_line_revision_id', t.wholesale_order_line_revision_id,
      'dispatch_requirement_id', t.dispatch_requirement_id,
      'fulfilment_allocation_line_revision_id', t.fulfilment_allocation_line_revision_id,
      'purchase_order_line_revision_id', t.purchase_order_line_revision_id,
      'supplier_receiving_evidence_id', t.supplier_receiving_evidence_id,
      'evidence_application_id', t.evidence_application_id,
      'dispatch_trip_id', dt.dispatch_trip_id,
      'dispatch_stop_id', ds.dispatch_stop_id,
      'dispatch_load_line_id', t.dispatch_load_line_id,
      'delivery_confirmation_id', t.delivery_confirmation_id
    ),
    'stage_statuses', pg_catalog.jsonb_build_object(
      'wholesale_order', wo.order_status,
      'purchase_order', po.purchase_order_status,
      'supplier_evidence', sre.evidence_status,
      'evidence_application', ea.application_status,
      'dispatch_load', dl.load_status,
      'dispatch_trip', dt.trip_status,
      'dispatch_stop', ds.stop_status,
      'delivery_confirmation', dc.confirmation_status
    ),
    'service_date', t.service_date,
    'customer_id', t.customer_id,
    'delivery_location_id', t.delivery_location_id,
    'ingredient_id', t.ingredient_id,
    'unit_id', t.unit_id,
    'quantities', pg_catalog.jsonb_build_object(
      'allocated', t.allocated_quantity,
      'applied_evidence', t.applied_quantity,
      'loaded', t.loaded_quantity,
      'delivered', t.delivered_quantity
    ),
    'evidence_readiness', (
      sre.evidence_status = 'VALID'
      and ea.application_status = 'VALID'
      and t.applied_quantity >= t.loaded_quantity
    ),
    'load_state', dl.load_status,
    'delivery_state', dc.delivery_outcome,
    'blockers', case
      when sre.evidence_status <> 'VALID' or ea.application_status <> 'VALID'
        then pg_catalog.jsonb_build_array('Supplier evidence is not currently valid.')
      when t.applied_quantity < t.loaded_quantity
        then pg_catalog.jsonb_build_array('Loaded quantity exceeds current applied evidence.')
      else '[]'::jsonb
    end,
    'warnings', '[]'::jsonb
  )
  into v_trace
  from atlas_reporting.supplier_direct_slice_trace t
  join atlas_planning.wholesale_orders wo on wo.wholesale_order_id = t.wholesale_order_id
  join atlas_procurement.purchase_order_line_revisions polr
    on polr.purchase_order_line_revision_id = t.purchase_order_line_revision_id
  join atlas_procurement.purchase_order_revisions por
    on por.purchase_order_revision_id = polr.purchase_order_revision_id
  join atlas_procurement.purchase_orders po on po.purchase_order_id = por.purchase_order_id
  join atlas_evidence.supplier_receiving_evidence sre
    on sre.supplier_receiving_evidence_id = t.supplier_receiving_evidence_id
  join atlas_evidence.evidence_applications ea
    on ea.evidence_application_id = t.evidence_application_id
  join atlas_dispatch.dispatch_load_lines dll
    on dll.dispatch_load_line_id = t.dispatch_load_line_id
  join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
  join atlas_dispatch.dispatch_trips dt on dt.dispatch_trip_id = dl.dispatch_trip_id
  join atlas_dispatch.dispatch_stops ds on ds.dispatch_stop_id = dll.dispatch_stop_id
  join atlas_dispatch.delivery_confirmations dc
    on dc.delivery_confirmation_id = t.delivery_confirmation_id
  where t.wholesale_order_line_revision_id = v_source_revision_id
  limit 1;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'PA-05B.v1',
    'trace', v_trace,
    'safe_operator_message', 'Authorized supplier-direct trace returned.',
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
exception
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The supplier-direct trace could not be returned safely.',
      'REPORTING',
      v_command_name
    );
end;
$$;

-- Runtime roles receive only the schemas, tables, and verbs needed by this
-- bounded function set. API roles still receive no domain-schema usage.
grant usage on schema atlas_core, atlas_admin, atlas_planning, atlas_procurement,
  atlas_evidence, atlas_dispatch, atlas_audit, atlas_api
  to atlas_command_runtime;
grant usage on schema atlas_core, atlas_admin, atlas_planning, atlas_procurement,
  atlas_evidence, atlas_dispatch, atlas_reporting, atlas_api
  to atlas_read_runtime;

grant select on
  atlas_core.actors,
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes,
  atlas_core.command_receipts,
  atlas_admin.delivery_locations,
  atlas_admin.units,
  atlas_admin.ingredients,
  atlas_admin.suppliers,
  atlas_planning.dispatch_requirements,
  atlas_planning.dispatch_requirement_revisions,
  atlas_planning.dispatch_requirement_line_revisions,
  atlas_procurement.fulfilment_allocations,
  atlas_procurement.fulfilment_allocation_revisions,
  atlas_procurement.fulfilment_allocation_line_revisions,
  atlas_procurement.purchase_orders,
  atlas_procurement.purchase_order_revisions,
  atlas_procurement.purchase_order_line_revisions,
  atlas_evidence.supplier_receiving_evidence,
  atlas_evidence.evidence_applications,
  atlas_dispatch.dispatch_plans,
  atlas_dispatch.dispatch_plan_requirements,
  atlas_dispatch.dispatch_trips,
  atlas_dispatch.dispatch_stops,
  atlas_dispatch.dispatch_loads,
  atlas_dispatch.dispatch_load_lines,
  atlas_dispatch.dispatch_load_line_applications,
  atlas_dispatch.delivery_confirmations
to atlas_command_runtime;

grant insert, update on atlas_core.command_receipts to atlas_command_runtime;
grant update on
  atlas_admin.delivery_locations,
  atlas_admin.units,
  atlas_admin.ingredients,
  atlas_admin.suppliers,
  atlas_planning.dispatch_requirements,
  atlas_planning.dispatch_requirement_revisions,
  atlas_planning.dispatch_requirement_line_revisions,
  atlas_procurement.fulfilment_allocations,
  atlas_procurement.fulfilment_allocation_line_revisions,
  atlas_procurement.purchase_orders,
  atlas_procurement.purchase_order_line_revisions,
  atlas_evidence.supplier_receiving_evidence,
  atlas_evidence.evidence_applications,
  atlas_dispatch.dispatch_loads,
  atlas_dispatch.dispatch_load_lines,
  atlas_dispatch.dispatch_load_line_applications,
  atlas_dispatch.delivery_confirmations,
  atlas_dispatch.dispatch_plans
to atlas_command_runtime;
grant insert on
  atlas_evidence.supplier_receiving_evidence,
  atlas_evidence.evidence_applications,
  atlas_dispatch.dispatch_loads,
  atlas_dispatch.dispatch_load_lines,
  atlas_dispatch.dispatch_load_line_applications,
  atlas_dispatch.delivery_confirmations,
  atlas_dispatch.delivery_confirmation_lines,
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_command_runtime;
grant select (delivery_confirmation_line_id)
  on atlas_dispatch.delivery_confirmation_lines to atlas_command_runtime;
grant select (domain_event_id)
  on atlas_audit.domain_events to atlas_command_runtime;
grant select (audit_event_id)
  on atlas_audit.audit_events to atlas_command_runtime;
grant select, update on
  atlas_dispatch.dispatch_trips,
  atlas_dispatch.dispatch_stops
to atlas_command_runtime;

grant select on
  atlas_core.actors,
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes,
  atlas_planning.wholesale_orders,
  atlas_planning.wholesale_order_lines,
  atlas_planning.wholesale_order_line_revisions,
  atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.purchase_handoff_lines,
  atlas_planning.purchase_handoff_line_revisions,
  atlas_planning.dispatch_requirements,
  atlas_planning.dispatch_requirement_lines,
  atlas_planning.dispatch_requirement_line_revisions,
  atlas_procurement.fulfilment_allocation_lines,
  atlas_procurement.fulfilment_allocation_line_revisions,
  atlas_procurement.purchase_orders,
  atlas_procurement.purchase_order_revisions,
  atlas_procurement.purchase_order_lines,
  atlas_procurement.purchase_order_line_revisions,
  atlas_evidence.supplier_receiving_evidence,
  atlas_evidence.evidence_applications,
  atlas_dispatch.dispatch_trips,
  atlas_dispatch.dispatch_stops,
  atlas_dispatch.dispatch_loads,
  atlas_dispatch.dispatch_load_lines,
  atlas_dispatch.dispatch_load_line_applications,
  atlas_dispatch.delivery_confirmations,
  atlas_dispatch.delivery_confirmation_lines,
  atlas_reporting.supplier_direct_slice_trace
to atlas_read_runtime;

-- RLS policies are runtime-role specific. No API role is named in a policy.
create policy pa_05b_command_select on atlas_core.actors
  for select to atlas_command_runtime using (true);
create policy pa_05b_read_select on atlas_core.actors
  for select to atlas_read_runtime using (true);
create policy pa_05b_command_select on atlas_core.actor_auth_subjects
  for select to atlas_command_runtime using (true);
create policy pa_05b_read_select on atlas_core.actor_auth_subjects
  for select to atlas_read_runtime using (true);
create policy pa_05b_command_select on atlas_core.roles
  for select to atlas_command_runtime using (true);
create policy pa_05b_read_select on atlas_core.roles
  for select to atlas_read_runtime using (true);
create policy pa_05b_command_select on atlas_core.capabilities
  for select to atlas_command_runtime using (true);
create policy pa_05b_read_select on atlas_core.capabilities
  for select to atlas_read_runtime using (true);
create policy pa_05b_command_select on atlas_core.role_capabilities
  for select to atlas_command_runtime using (true);
create policy pa_05b_read_select on atlas_core.role_capabilities
  for select to atlas_read_runtime using (true);
create policy pa_05b_command_select on atlas_core.actor_role_memberships
  for select to atlas_command_runtime using (true);
create policy pa_05b_read_select on atlas_core.actor_role_memberships
  for select to atlas_read_runtime using (true);
create policy pa_05b_command_select on atlas_core.actor_scopes
  for select to atlas_command_runtime using (true);
create policy pa_05b_read_select on atlas_core.actor_scopes
  for select to atlas_read_runtime using (true);
create policy pa_05b_command_all on atlas_core.command_receipts
  for all to atlas_command_runtime using (true) with check (true);

create policy pa_05b_command_select on atlas_admin.delivery_locations
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_select on atlas_admin.units
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_select on atlas_admin.ingredients
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_select on atlas_admin.suppliers
  for select to atlas_command_runtime using (true);

create policy pa_05b_command_select on atlas_planning.dispatch_requirements
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_select on atlas_planning.dispatch_requirement_revisions
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_select on atlas_planning.dispatch_requirement_line_revisions
  for select to atlas_command_runtime using (true);

create policy pa_05b_command_all on atlas_procurement.fulfilment_allocations
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_select on atlas_procurement.fulfilment_allocation_revisions
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_all on atlas_procurement.fulfilment_allocation_line_revisions
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_all on atlas_procurement.purchase_orders
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_select on atlas_procurement.purchase_order_revisions
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_all on atlas_procurement.purchase_order_line_revisions
  for all to atlas_command_runtime using (true) with check (true);

create policy pa_05b_command_all on atlas_evidence.supplier_receiving_evidence
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_all on atlas_evidence.evidence_applications
  for all to atlas_command_runtime using (true) with check (true);

create policy pa_05b_command_select on atlas_dispatch.dispatch_plans
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_select on atlas_dispatch.dispatch_plan_requirements
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_all on atlas_dispatch.dispatch_trips
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_all on atlas_dispatch.dispatch_stops
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_all on atlas_dispatch.dispatch_loads
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_all on atlas_dispatch.dispatch_load_lines
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_all on atlas_dispatch.dispatch_load_line_applications
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_all on atlas_dispatch.delivery_confirmations
  for all to atlas_command_runtime using (true) with check (true);
create policy pa_05b_command_insert on atlas_dispatch.delivery_confirmation_lines
  for insert to atlas_command_runtime with check (true);
create policy pa_05b_command_select on atlas_dispatch.delivery_confirmation_lines
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_insert on atlas_audit.domain_events
  for insert to atlas_command_runtime with check (true);
create policy pa_05b_command_select on atlas_audit.domain_events
  for select to atlas_command_runtime using (true);
create policy pa_05b_command_insert on atlas_audit.audit_events
  for insert to atlas_command_runtime with check (true);
create policy pa_05b_command_select on atlas_audit.audit_events
  for select to atlas_command_runtime using (true);

create policy pa_05b_read_select on atlas_planning.wholesale_orders
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_planning.wholesale_order_lines
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_planning.wholesale_order_line_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_planning.confirmed_need_lines
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_planning.confirmed_need_line_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_planning.purchase_handoff_lines
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_planning.purchase_handoff_line_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_planning.dispatch_requirements
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_planning.dispatch_requirement_lines
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_planning.dispatch_requirement_line_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_procurement.fulfilment_allocation_lines
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_procurement.fulfilment_allocation_line_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_procurement.purchase_orders
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_procurement.purchase_order_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_procurement.purchase_order_lines
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_procurement.purchase_order_line_revisions
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_evidence.supplier_receiving_evidence
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_evidence.evidence_applications
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_dispatch.dispatch_trips
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_dispatch.dispatch_stops
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_dispatch.dispatch_loads
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_dispatch.dispatch_load_lines
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_dispatch.dispatch_load_line_applications
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_dispatch.delivery_confirmations
  for select to atlas_read_runtime using (true);
create policy pa_05b_read_select on atlas_dispatch.delivery_confirmation_lines
  for select to atlas_read_runtime using (true);

alter function atlas_core.pa_05b_safe_uuid(text) owner to atlas_owner;
alter function atlas_core.pa_05b_safe_bigint(text) owner to atlas_owner;
alter function atlas_core.pa_05b_safe_numeric(text) owner to atlas_owner;
alter function atlas_core.pa_05b_safe_timestamptz(text) owner to atlas_owner;
alter function atlas_core.pa_05b_current_auth_subject() owner to atlas_owner;
alter function atlas_core.pa_05b_command_error(jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint)
  owner to atlas_owner;
alter function atlas_core.pa_05b_validate_command_request(jsonb, text, text) owner to atlas_owner;
alter function atlas_core.pa_05b_resolve_actor(jsonb, text, text) owner to atlas_owner;
alter function atlas_core.pa_05b_authorize_actor(jsonb, uuid, text, text, text, uuid, uuid, uuid)
  owner to atlas_owner;
alter function atlas_core.pa_05b_request_hash(jsonb) owner to atlas_owner;
alter function atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text) owner to atlas_owner;
alter function atlas_core.pa_05b_finish_command(uuid, jsonb, boolean) owner to atlas_owner;
alter function atlas_core.pa_05b_validate_trace_request(jsonb) owner to atlas_owner;

grant atlas_command_runtime, atlas_read_runtime to postgres with set true;
grant create on schema atlas_api to atlas_command_runtime, atlas_read_runtime;

alter function atlas_api.record_supplier_receiving_evidence(jsonb) owner to atlas_command_runtime;
alter function atlas_api.apply_supplier_evidence_to_allocation(jsonb) owner to atlas_command_runtime;
alter function atlas_api.confirm_dispatch_load(jsonb) owner to atlas_command_runtime;
alter function atlas_api.record_dispatch_departure(jsonb) owner to atlas_command_runtime;
alter function atlas_api.confirm_successful_delivery(jsonb) owner to atlas_command_runtime;
alter function atlas_api.get_supplier_direct_trace(jsonb) owner to atlas_read_runtime;

revoke execute on all functions in schema atlas_core from public, anon, authenticated, service_role;
revoke execute on all functions in schema atlas_api from public, anon, authenticated, service_role;

grant execute on function atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_numeric(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint),
  atlas_core.pa_05b_validate_command_request(jsonb, text, text),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(jsonb, uuid, text, text, text, uuid, uuid, uuid),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean)
to atlas_command_runtime;

grant execute on function atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint),
  atlas_core.pa_05b_validate_trace_request(jsonb),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(jsonb, uuid, text, text, text, uuid, uuid, uuid)
to atlas_read_runtime;

grant usage on schema atlas_api to authenticated;
grant execute on function atlas_api.record_supplier_receiving_evidence(jsonb),
  atlas_api.apply_supplier_evidence_to_allocation(jsonb),
  atlas_api.confirm_dispatch_load(jsonb),
  atlas_api.record_dispatch_departure(jsonb),
  atlas_api.confirm_successful_delivery(jsonb),
  atlas_api.get_supplier_direct_trace(jsonb)
to authenticated;

comment on function atlas_api.record_supplier_receiving_evidence(jsonb)
  is 'PA-05B hardened supplier receiving evidence command; no Warehouse or Procurement mutation.';
comment on function atlas_api.apply_supplier_evidence_to_allocation(jsonb)
  is 'PA-05B hardened evidence application command with evidence/allocation quantity caps.';
comment on function atlas_api.confirm_dispatch_load(jsonb)
  is 'PA-05B hardened load command consuming one exact current evidence application.';
comment on function atlas_api.record_dispatch_departure(jsonb)
  is 'PA-05B hardened departure command that revalidates authoritative evidence under locks.';
comment on function atlas_api.confirm_successful_delivery(jsonb)
  is 'PA-05B hardened successful-only delivery command with exact load reconciliation.';
comment on function atlas_api.get_supplier_direct_trace(jsonb)
  is 'PA-05B shaped authorized supplier-direct source-to-delivery read; never a write safety gate.';

comment on schema atlas_api
  is 'Function-only Atlas Data API boundary; PA-05B exposes five bounded write commands and one shaped read.';

revoke create on schema atlas_api from atlas_command_runtime, atlas_read_runtime;
revoke atlas_command_runtime, atlas_read_runtime from postgres;
