-- PA-05D: bounded Planning command family for supplier-direct wholesale Slice 1.
--
-- This migration adds four reviewed Planning commands, narrow race-safety
-- constraints, and one command-family runtime. It creates no Procurement,
-- Evidence, Dispatch-execution, Warehouse, Storage, seed, or hosted-project fact.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'atlas_planning_command_runtime') then
    create role atlas_planning_command_runtime nologin noinherit;
  end if;
end
$$;

drop index atlas_planning.wholesale_orders_customer_reference_key;

create unique index wholesale_orders_active_customer_reference_key
  on atlas_planning.wholesale_orders (customer_id, customer_order_reference)
  where customer_order_reference is not null and order_status <> 'CANCELLED';

create unique index confirmed_need_batches_wholesale_order_key
  on atlas_planning.confirmed_need_batches (wholesale_order_id);

create unique index dispatch_requirement_revisions_released_handoff_key
  on atlas_planning.dispatch_requirement_revisions (purchase_handoff_revision_id)
  where is_current and revision_status = 'RELEASED';

create or replace function atlas_core.pa_05d_safe_date(value text)
returns date
language plpgsql
immutable
set search_path = ''
as $$
begin
  if value is null or value !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    return null;
  end if;
  return value::date;
exception
  when invalid_datetime_format or datetime_field_overflow then
    return null;
end;
$$;

-- Planning runtime: function ownership plus only the relation verbs needed by
-- this command family. Lock-only UPDATE grants have no matching update policy.
grant usage on schema atlas_core, atlas_admin, atlas_planning, atlas_audit, atlas_api
  to atlas_planning_command_runtime;

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
  atlas_admin.delivery_locations,
  atlas_admin.ingredients,
  atlas_admin.units,
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
  atlas_planning.dispatch_requirements,
  atlas_planning.dispatch_requirement_revisions,
  atlas_planning.dispatch_requirement_lines,
  atlas_planning.dispatch_requirement_line_revisions
to atlas_planning_command_runtime;

grant insert, update on atlas_core.command_receipts to atlas_planning_command_runtime;
grant update on atlas_admin.customers, atlas_admin.delivery_locations,
  atlas_admin.ingredients, atlas_admin.units,
  atlas_planning.wholesale_orders, atlas_planning.wholesale_order_lines,
  atlas_planning.wholesale_order_line_revisions,
  atlas_planning.confirmed_need_batches, atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_approval_snapshots,
  atlas_planning.confirmed_need_snapshot_lines,
  atlas_planning.purchase_handoff_batches, atlas_planning.purchase_handoff_revisions,
  atlas_planning.purchase_handoff_lines, atlas_planning.purchase_handoff_line_revisions,
  atlas_planning.purchase_demand_references
to atlas_planning_command_runtime;

grant insert on
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
  atlas_planning.dispatch_requirements,
  atlas_planning.dispatch_requirement_revisions,
  atlas_planning.dispatch_requirement_lines,
  atlas_planning.dispatch_requirement_line_revisions,
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_planning_command_runtime;
grant select (domain_event_id) on atlas_audit.domain_events to atlas_planning_command_runtime;
grant select (audit_event_id) on atlas_audit.audit_events to atlas_planning_command_runtime;

create policy pa_05d_planning_select on atlas_core.actors for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_select on atlas_core.actor_auth_subjects for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_select on atlas_core.roles for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_select on atlas_core.capabilities for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_select on atlas_core.role_capabilities for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_select on atlas_core.actor_role_memberships for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_select on atlas_core.actor_scopes for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_receipt_select on atlas_core.command_receipts for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_receipt_insert on atlas_core.command_receipts for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_receipt_update on atlas_core.command_receipts for update to atlas_planning_command_runtime using (true) with check (true);

create policy pa_05d_planning_select on atlas_admin.customers for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_select on atlas_admin.delivery_locations for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_select on atlas_admin.ingredients for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_select on atlas_admin.units for select to atlas_planning_command_runtime using (true);

create policy pa_05d_planning_select on atlas_planning.wholesale_orders for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.wholesale_orders for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_update on atlas_planning.wholesale_orders for update to atlas_planning_command_runtime using (true) with check (true);
create policy pa_05d_planning_select on atlas_planning.wholesale_order_lines for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.wholesale_order_lines for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.wholesale_order_line_revisions for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.wholesale_order_line_revisions for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_update on atlas_planning.wholesale_order_line_revisions for update to atlas_planning_command_runtime using (true) with check (true);

create policy pa_05d_planning_select on atlas_planning.confirmed_need_batches for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.confirmed_need_batches for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.confirmed_need_lines for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.confirmed_need_lines for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.confirmed_need_line_revisions for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.confirmed_need_line_revisions for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.confirmed_need_approval_snapshots for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.confirmed_need_approval_snapshots for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.confirmed_need_snapshot_lines for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.confirmed_need_snapshot_lines for insert to atlas_planning_command_runtime with check (true);

create policy pa_05d_planning_select on atlas_planning.purchase_handoff_batches for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.purchase_handoff_batches for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.purchase_handoff_revisions for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.purchase_handoff_revisions for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.purchase_handoff_lines for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.purchase_handoff_lines for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.purchase_handoff_line_revisions for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.purchase_handoff_line_revisions for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.purchase_demand_references for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.purchase_demand_references for insert to atlas_planning_command_runtime with check (true);

create policy pa_05d_planning_select on atlas_planning.dispatch_requirements for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.dispatch_requirements for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.dispatch_requirement_revisions for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.dispatch_requirement_revisions for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.dispatch_requirement_lines for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.dispatch_requirement_lines for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_select on atlas_planning.dispatch_requirement_line_revisions for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_insert on atlas_planning.dispatch_requirement_line_revisions for insert to atlas_planning_command_runtime with check (true);

create policy pa_05d_planning_audit_insert on atlas_audit.domain_events for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_audit_select on atlas_audit.domain_events for select to atlas_planning_command_runtime using (true);
create policy pa_05d_planning_audit_insert on atlas_audit.audit_events for insert to atlas_planning_command_runtime with check (true);
create policy pa_05d_planning_audit_select on atlas_audit.audit_events for select to atlas_planning_command_runtime using (true);

create or replace function atlas_api.release_wholesale_order(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'release_wholesale_order';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_wholesale_order_id uuid;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_service_date date;
  v_order_status text;
  v_order_version bigint;
  v_customer_status text;
  v_customer_type text;
  v_location_status text;
  v_location_customer_id uuid;
  v_line_count integer;
  v_current_count integer;
  v_confirmed_need_batch_id uuid;
  v_confirmed_need_line_id uuid;
  v_confirmed_need_line_revision_id uuid;
  v_snapshot_id uuid;
  v_line record;
  v_line_ids jsonb := '[]'::jsonb;
  v_line_revision_ids jsonb := '[]'::jsonb;
  v_snapshot_line_ids jsonb := '[]'::jsonb;
  v_snapshot_line_id uuid;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05d_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;
  v_wholesale_order_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'wholesale_order_id');
  if v_wholesale_order_id is null or (select count(*) from pg_catalog.jsonb_object_keys(v_payload)) <> 1 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'Provide only a valid wholesale_order_id.',
      'PLANNING', v_command_name
    );
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'PLANNING', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select wo.customer_id, wo.delivery_location_id, wo.service_date, wo.order_status, wo.version
    into v_customer_id, v_delivery_location_id, v_service_date, v_order_status, v_order_version
  from atlas_planning.wholesale_orders wo
  where wo.wholesale_order_id = v_wholesale_order_id;
  if not found then
    return atlas_core.pa_05b_command_error(request, 'VALIDATION_FAILED', 'The wholesale order could not be validated.', 'PLANNING', v_command_name);
  end if;

  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'wholesale_order.release', 'PLANNING', v_command_name,
    v_customer_id, v_delivery_location_id, null
  );
  if v_error is not null then return v_error; end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'PLANNING', 'wholesale-order:' || v_wholesale_order_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1 from atlas_admin.customers c where c.customer_id = v_customer_id for key share;
  perform 1 from atlas_admin.delivery_locations dl where dl.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_admin.ingredients i
    where i.ingredient_id in (
      select wolr.ingredient_id
      from atlas_planning.wholesale_order_lines wol
      join atlas_planning.wholesale_order_line_revisions wolr on wolr.wholesale_order_line_id = wol.wholesale_order_line_id
      where wol.wholesale_order_id = v_wholesale_order_id and wolr.is_current
    ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (
      select wolr.unit_id
      from atlas_planning.wholesale_order_lines wol
      join atlas_planning.wholesale_order_line_revisions wolr on wolr.wholesale_order_line_id = wol.wholesale_order_line_id
      where wol.wholesale_order_id = v_wholesale_order_id and wolr.is_current
    ) order by u.unit_id for key share;
  perform 1 from atlas_planning.wholesale_orders wo where wo.wholesale_order_id = v_wholesale_order_id for update;
  perform 1 from atlas_planning.wholesale_order_lines wol
    where wol.wholesale_order_id = v_wholesale_order_id order by wol.wholesale_order_line_id for key share;
  perform 1 from atlas_planning.wholesale_order_line_revisions wolr
    where wolr.wholesale_order_line_id in (
      select wol.wholesale_order_line_id from atlas_planning.wholesale_order_lines wol
      where wol.wholesale_order_id = v_wholesale_order_id
    ) and wolr.is_current order by wolr.wholesale_order_line_revision_id for update;

  select wo.customer_id, wo.delivery_location_id, wo.service_date, wo.order_status, wo.version,
         c.customer_type, c.customer_status, dl.customer_id, dl.location_status
    into v_customer_id, v_delivery_location_id, v_service_date, v_order_status, v_order_version,
         v_customer_type, v_customer_status, v_location_customer_id, v_location_status
  from atlas_planning.wholesale_orders wo
  join atlas_admin.customers c on c.customer_id = wo.customer_id
  join atlas_admin.delivery_locations dl on dl.delivery_location_id = wo.delivery_location_id
  where wo.wholesale_order_id = v_wholesale_order_id;

  if v_order_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION', 'The wholesale order changed. Refresh before release.',
      'PLANNING', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_wholesale_order_id), v_order_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_line_count
  from atlas_planning.wholesale_order_lines wol where wol.wholesale_order_id = v_wholesale_order_id;
  select count(*)::integer into v_current_count
  from atlas_planning.wholesale_order_lines wol
  join atlas_planning.wholesale_order_line_revisions wolr on wolr.wholesale_order_line_id = wol.wholesale_order_line_id
  join atlas_admin.ingredients i on i.ingredient_id = wolr.ingredient_id
  join atlas_admin.units u on u.unit_id = wolr.unit_id
  where wol.wholesale_order_id = v_wholesale_order_id
    and wolr.is_current and wolr.revision_status = 'DRAFT' and wolr.requested_quantity > 0
    and i.ingredient_status = 'ACTIVE' and u.unit_status = 'ACTIVE';

  if v_order_status <> 'DRAFT' or v_line_count < 1 or v_current_count <> v_line_count
     or v_customer_type <> 'WHOLESALE' or v_customer_status <> 'ACTIVE'
     or v_location_status <> 'ACTIVE' or v_location_customer_id <> v_customer_id
     or exists (select 1 from atlas_planning.confirmed_need_batches cnb where cnb.wholesale_order_id = v_wholesale_order_id) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'Wholesale release requires one complete Draft order with active references and no prior Confirmed Need.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  update atlas_planning.wholesale_orders wo
  set order_status = 'RELEASED', version = wo.version + 1,
      approved_by_actor_id = v_actor_id, approved_at = pg_catalog.transaction_timestamp(),
      released_by_actor_id = v_actor_id, released_at = pg_catalog.transaction_timestamp(),
      updated_at = pg_catalog.transaction_timestamp()
  where wo.wholesale_order_id = v_wholesale_order_id;

  update atlas_planning.wholesale_order_line_revisions wolr
  set revision_status = 'RELEASED'
  where wolr.is_current and wolr.wholesale_order_line_id in (
    select wol.wholesale_order_line_id from atlas_planning.wholesale_order_lines wol
    where wol.wholesale_order_id = v_wholesale_order_id
  );

  insert into atlas_planning.confirmed_need_batches (
    wholesale_order_id, period_start, period_end, batch_status, version,
    created_by_actor_id, approved_by_actor_id, approved_at, released_by_actor_id, released_at
  ) values (
    v_wholesale_order_id, v_service_date, v_service_date,
    'RELEASED_FOR_PURCHASE_HANDOFF', 1, v_actor_id, v_actor_id,
    pg_catalog.transaction_timestamp(), v_actor_id, pg_catalog.transaction_timestamp()
  ) returning confirmed_need_batch_id into v_confirmed_need_batch_id;

  insert into atlas_planning.confirmed_need_approval_snapshots (
    confirmed_need_batch_id, approved_version, approved_by_actor_id, approved_at, command_id
  ) values (
    v_confirmed_need_batch_id, 1, v_actor_id, pg_catalog.transaction_timestamp(),
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
  ) returning confirmed_need_approval_snapshot_id into v_snapshot_id;

  for v_line in
    select wol.wholesale_order_line_id, wolr.wholesale_order_line_revision_id,
           wolr.ingredient_id, wolr.requested_quantity, wolr.unit_id, i.ingredient_name
    from atlas_planning.wholesale_order_lines wol
    join atlas_planning.wholesale_order_line_revisions wolr on wolr.wholesale_order_line_id = wol.wholesale_order_line_id
    join atlas_admin.ingredients i on i.ingredient_id = wolr.ingredient_id
    where wol.wholesale_order_id = v_wholesale_order_id and wolr.is_current
    order by wol.wholesale_order_line_id
  loop
    insert into atlas_planning.confirmed_need_lines (
      confirmed_need_batch_id, wholesale_order_line_id
    ) values (v_confirmed_need_batch_id, v_line.wholesale_order_line_id)
    returning confirmed_need_line_id into v_confirmed_need_line_id;
    v_line_ids := v_line_ids || pg_catalog.jsonb_build_array(v_confirmed_need_line_id);

    insert into atlas_planning.confirmed_need_line_revisions (
      confirmed_need_line_id, revision_number, wholesale_order_line_revision_id,
      ingredient_id, theoretical_quantity, confirmed_quantity, unit_id,
      revision_status, is_current, command_id, created_by_actor_id
    ) values (
      v_confirmed_need_line_id, 1, v_line.wholesale_order_line_revision_id,
      v_line.ingredient_id, v_line.requested_quantity, v_line.requested_quantity,
      v_line.unit_id, 'RELEASED', true,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'), v_actor_id
    ) returning confirmed_need_line_revision_id into v_confirmed_need_line_revision_id;
    v_line_revision_ids := v_line_revision_ids || pg_catalog.jsonb_build_array(v_confirmed_need_line_revision_id);

    insert into atlas_planning.confirmed_need_snapshot_lines (
      confirmed_need_approval_snapshot_id, confirmed_need_line_revision_id,
      ingredient_id, approved_quantity, unit_id, ingredient_name_snapshot
    ) values (
      v_snapshot_id, v_confirmed_need_line_revision_id, v_line.ingredient_id,
      v_line.requested_quantity, v_line.unit_id, v_line.ingredient_name
    ) returning confirmed_need_snapshot_line_id into v_snapshot_line_id;
    v_snapshot_line_ids := v_snapshot_line_ids || pg_catalog.jsonb_build_array(v_snapshot_line_id);
  end loop;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at, payload_summary
  ) values (
    'WholesaleOrderReleased', 'PLANNING', 'WholesaleOrder', v_wholesale_order_id, v_order_version + 1,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object('confirmed_need_batch_id', v_confirmed_need_batch_id, 'line_count', v_line_count)
  ) returning domain_event_id into v_domain_event_id;
  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id,
    aggregate_version_before, aggregate_version_after, command_receipt_id,
    command_id, correlation_id, actor_id, reason_code, reason_note,
    before_summary, after_summary, source_interface, occurred_at
  ) values (
    'WholesaleOrderReleased', 'PLANNING', 'WholesaleOrder', v_wholesale_order_id,
    v_order_version, v_order_version + 1, v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status', 'DRAFT'),
    pg_catalog.jsonb_build_object('status', 'RELEASED', 'confirmed_need_batch_id', v_confirmed_need_batch_id),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id', 'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'wholesale_order_id', v_wholesale_order_id,
      'confirmed_need_batch_id', v_confirmed_need_batch_id,
      'confirmed_need_line_ids', v_line_ids,
      'confirmed_need_line_revision_ids', v_line_revision_ids,
      'confirmed_need_approval_snapshot_id', v_snapshot_id,
      'confirmed_need_snapshot_line_ids', v_snapshot_line_ids
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'wholesale_order_version', v_order_version + 1, 'confirmed_need_batch_version', 1
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Wholesale order and Confirmed Need released.',
    'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(request, 'RETRYABLE_CONCURRENCY_FAILURE', 'The command could not acquire a safe transaction state. Retry the exact request.', 'PLANNING', v_command_name, true);
  when unique_violation then
    return atlas_core.pa_05b_command_error(request, 'INVARIANT_VIOLATION', 'A Confirmed Need already exists for this wholesale order.', 'PLANNING', v_command_name);
  when others then
    return atlas_core.pa_05b_command_error(request, 'INTERNAL_COMMAND_FAILURE', 'The wholesale order could not be released safely.', 'PLANNING', v_command_name);
end;
$$;

create or replace function atlas_core.pa_05d_validate_command_request(
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
  v_payload jsonb;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb), 'VALIDATION_FAILED',
      'The command request must be a JSON object.', 'PLANNING', command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'request', 'message', 'A JSON object is required.')
      )
    );
  end if;

  if request ->> 'contract_version' is distinct from 'PA-05D.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use PA-05D.v1.')
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
  else
    v_payload := request -> 'payload';
    if v_payload ?| array[
      'actor_id', 'requested_by_actor_id', 'approved_by_actor_id', 'released_by_actor_id', 'table_name',
      'status', 'order_status', 'batch_status', 'handoff_status', 'revision_status',
      'wholesale_order_line_id', 'wholesale_order_line_revision_id',
      'confirmed_need_line_id', 'confirmed_need_line_revision_id',
      'purchase_handoff_batch_id', 'purchase_handoff_line_id',
      'purchase_handoff_line_revision_id', 'dispatch_requirement_id',
      'dispatch_requirement_revision_id', 'dispatch_requirement_line_id'
    ] then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload',
          'message', 'Actor, override, lifecycle, table, and generated aggregate fields are not accepted.'
        )
      );
    end if;
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The command envelope is invalid.',
      'PLANNING', command_name, false, v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_api.record_wholesale_source(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'record_wholesale_source';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_customer_order_reference text;
  v_service_date date;
  v_lines jsonb;
  v_line jsonb;
  v_line_count integer;
  v_source_line_number bigint;
  v_ingredient_id uuid;
  v_wholesale_order_line_revision_id uuid;
  v_unit_id uuid;
  v_quantity numeric;
  v_customer_type text;
  v_customer_status text;
  v_location_customer_id uuid;
  v_location_status text;
  v_wholesale_order_id uuid;
  v_wholesale_order_line_id uuid;
  v_line_ids jsonb := '[]'::jsonb;
  v_line_revision_ids jsonb := '[]'::jsonb;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05d_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;

  v_customer_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'customer_id');
  v_delivery_location_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'delivery_location_id');
  v_customer_order_reference := pg_catalog.btrim(coalesce(v_payload ->> 'customer_order_reference', ''));
  v_service_date := atlas_core.pa_05d_safe_date(v_payload ->> 'service_date');
  v_lines := v_payload -> 'lines';

  if v_payload ? 'delegated_actor_id' then
    return atlas_core.pa_05b_command_error(
      request, 'DELEGATION_NOT_SUPPORTED', 'Delegation is not supported for this command.',
      'PLANNING', v_command_name
    );
  end if;

  if not (v_payload ?& array['customer_id', 'delivery_location_id', 'customer_order_reference', 'service_date', 'lines'])
     or v_payload - array['customer_id', 'delivery_location_id', 'customer_order_reference', 'service_date', 'lines'] <> '{}'::jsonb
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
     or v_customer_id is null or v_delivery_location_id is null
     or v_customer_order_reference = '' or pg_catalog.length(v_customer_order_reference) > 200
     or v_service_date is null
     or v_lines is null or pg_catalog.jsonb_typeof(v_lines) <> 'array' then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'The wholesale source payload is incomplete or invalid.',
      'PLANNING', v_command_name, false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Customer, location, reference, service date, and lines are required; expected_version must be 1.')
      )
    );
  end if;

  v_line_count := pg_catalog.jsonb_array_length(v_lines);
  if v_line_count < 1 or v_line_count > 100 then
    return atlas_core.pa_05b_command_error(
      request, 'VALIDATION_FAILED', 'Wholesale source requires between 1 and 100 lines.',
      'PLANNING', v_command_name, false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Provide between 1 and 100 lines.')
      )
    );
  end if;

  for v_line in select value from pg_catalog.jsonb_array_elements(v_lines)
  loop
    if pg_catalog.jsonb_typeof(v_line) <> 'object' then
      return atlas_core.pa_05b_command_error(request, 'VALIDATION_FAILED', 'Each wholesale source line must be an object.', 'PLANNING', v_command_name);
    end if;
    v_source_line_number := atlas_core.pa_05b_safe_bigint(v_line ->> 'source_line_number');
    v_ingredient_id := atlas_core.pa_05b_safe_uuid(v_line ->> 'ingredient_id');
    v_unit_id := atlas_core.pa_05b_safe_uuid(v_line ->> 'unit_id');
    v_quantity := atlas_core.pa_05b_safe_numeric(v_line ->> 'requested_quantity');
    if not (v_line ?& array['source_line_number', 'ingredient_id', 'requested_quantity', 'unit_id'])
       or v_line - array['source_line_number', 'ingredient_id', 'requested_quantity', 'unit_id'] <> '{}'::jsonb
       or v_source_line_number is null or v_source_line_number <= 0 or v_source_line_number > 2147483647
       or v_ingredient_id is null or v_unit_id is null or v_quantity is null or v_quantity <= 0 then
      return atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED', 'A wholesale source line is incomplete or invalid.',
        'PLANNING', v_command_name, false,
        pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('field', 'payload.lines', 'message', 'Use unique positive line numbers, active ingredient/unit IDs, and positive quantities.')
        )
      );
    end if;
  end loop;

  if (
    select count(distinct atlas_core.pa_05b_safe_bigint(x.value ->> 'source_line_number'))
    from pg_catalog.jsonb_array_elements(v_lines) x
  ) <> v_line_count then
    return atlas_core.pa_05b_command_error(request, 'VALIDATION_FAILED', 'Wholesale source line numbers must be unique.', 'PLANNING', v_command_name);
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'PLANNING', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select c.customer_type, c.customer_status
    into v_customer_type, v_customer_status
  from atlas_admin.customers c where c.customer_id = v_customer_id;
  select dl.customer_id, dl.location_status
    into v_location_customer_id, v_location_status
  from atlas_admin.delivery_locations dl where dl.delivery_location_id = v_delivery_location_id;
  if v_customer_type is null or v_location_customer_id is null then
    return atlas_core.pa_05b_command_error(request, 'VALIDATION_FAILED', 'The wholesale customer or delivery location could not be validated.', 'PLANNING', v_command_name);
  end if;

  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'wholesale_source.record', 'PLANNING', v_command_name,
    v_customer_id, v_delivery_location_id, null
  );
  if v_error is not null then return v_error; end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'PLANNING',
    'customer-reference:' || v_customer_id::text || ':' || v_customer_order_reference
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1 from atlas_admin.customers c where c.customer_id = v_customer_id for update;
  perform 1 from atlas_admin.delivery_locations dl where dl.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_admin.ingredients i
    where i.ingredient_id in (select atlas_core.pa_05b_safe_uuid(x.value ->> 'ingredient_id') from pg_catalog.jsonb_array_elements(v_lines) x)
    order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u
    where u.unit_id in (select atlas_core.pa_05b_safe_uuid(x.value ->> 'unit_id') from pg_catalog.jsonb_array_elements(v_lines) x)
    order by u.unit_id for key share;

  select c.customer_type, c.customer_status, dl.customer_id, dl.location_status
    into v_customer_type, v_customer_status, v_location_customer_id, v_location_status
  from atlas_admin.customers c
  join atlas_admin.delivery_locations dl on dl.delivery_location_id = v_delivery_location_id
  where c.customer_id = v_customer_id;

  if v_customer_type <> 'WHOLESALE' or v_customer_status <> 'ACTIVE'
     or v_location_customer_id <> v_customer_id or v_location_status <> 'ACTIVE'
     or (select count(distinct i.ingredient_id) from atlas_admin.ingredients i
         where i.ingredient_status = 'ACTIVE' and i.ingredient_id in
           (select atlas_core.pa_05b_safe_uuid(x.value ->> 'ingredient_id') from pg_catalog.jsonb_array_elements(v_lines) x))
        <> (select count(distinct atlas_core.pa_05b_safe_uuid(x.value ->> 'ingredient_id')) from pg_catalog.jsonb_array_elements(v_lines) x)
     or (select count(distinct u.unit_id) from atlas_admin.units u
         where u.unit_status = 'ACTIVE' and u.unit_id in
           (select atlas_core.pa_05b_safe_uuid(x.value ->> 'unit_id') from pg_catalog.jsonb_array_elements(v_lines) x))
        <> (select count(distinct atlas_core.pa_05b_safe_uuid(x.value ->> 'unit_id')) from pg_catalog.jsonb_array_elements(v_lines) x) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'The wholesale customer, matching delivery location, ingredients, and units must remain active.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1 from atlas_planning.wholesale_orders wo
    where wo.customer_id = v_customer_id
      and wo.customer_order_reference = v_customer_order_reference
      and wo.order_status <> 'CANCELLED'
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION', 'The customer order reference is already active.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  insert into atlas_planning.wholesale_orders (
    customer_id, delivery_location_id, customer_order_reference, service_date,
    order_status, version, created_by_actor_id
  ) values (
    v_customer_id, v_delivery_location_id, v_customer_order_reference, v_service_date,
    'DRAFT', 1, v_actor_id
  ) returning wholesale_order_id into v_wholesale_order_id;

  for v_line in
    select value from pg_catalog.jsonb_array_elements(v_lines)
    order by atlas_core.pa_05b_safe_bigint(value ->> 'source_line_number')
  loop
    insert into atlas_planning.wholesale_order_lines (
      wholesale_order_id, source_line_number
    ) values (
      v_wholesale_order_id, atlas_core.pa_05b_safe_bigint(v_line ->> 'source_line_number')::integer
    ) returning wholesale_order_line_id into v_wholesale_order_line_id;
    v_line_ids := v_line_ids || pg_catalog.jsonb_build_array(v_wholesale_order_line_id);

    insert into atlas_planning.wholesale_order_line_revisions (
      wholesale_order_line_id, revision_number, ingredient_id, requested_quantity,
      unit_id, revision_status, is_current, command_id, created_by_actor_id
    ) values (
      v_wholesale_order_line_id, 1,
      atlas_core.pa_05b_safe_uuid(v_line ->> 'ingredient_id'),
      atlas_core.pa_05b_safe_numeric(v_line ->> 'requested_quantity'),
      atlas_core.pa_05b_safe_uuid(v_line ->> 'unit_id'),
      'DRAFT', true, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'), v_actor_id
    ) returning wholesale_order_line_revision_id into v_wholesale_order_line_revision_id;
    v_line_revision_ids := v_line_revision_ids || pg_catalog.jsonb_build_array(v_wholesale_order_line_revision_id);
  end loop;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at, payload_summary
  ) values (
    'WholesaleOrderRecorded', 'PLANNING', 'WholesaleOrder', v_wholesale_order_id, 1,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object('customer_id', v_customer_id, 'delivery_location_id', v_delivery_location_id, 'service_date', v_service_date, 'line_count', v_line_count)
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version_after,
    command_receipt_id, command_id, correlation_id, actor_id, reason_code, reason_note,
    after_summary, source_interface, occurred_at
  ) values (
    'WholesaleOrderRecorded', 'PLANNING', 'WholesaleOrder', v_wholesale_order_id, 1,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status', 'DRAFT', 'line_count', v_line_count),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id', 'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'wholesale_order_id', v_wholesale_order_id,
      'wholesale_order_line_ids', v_line_ids,
      'wholesale_order_line_revision_ids', v_line_revision_ids
    ),
    'new_versions', pg_catalog.jsonb_build_object('wholesale_order_version', 1),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Wholesale source recorded in Draft.',
    'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(request, 'RETRYABLE_CONCURRENCY_FAILURE', 'The command could not acquire a safe transaction state. Retry the exact request.', 'PLANNING', v_command_name, true);
  when unique_violation then
    return atlas_core.pa_05b_command_error(request, 'INVARIANT_VIOLATION', 'The wholesale source conflicts with an existing active record.', 'PLANNING', v_command_name);
  when others then
    return atlas_core.pa_05b_command_error(request, 'INTERNAL_COMMAND_FAILURE', 'The wholesale source could not be recorded safely.', 'PLANNING', v_command_name);
end;
$$;

create or replace function atlas_api.release_purchase_handoff(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'release_purchase_handoff';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_confirmed_need_batch_id uuid;
  v_wholesale_order_id uuid;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_service_date date;
  v_batch_status text;
  v_batch_version bigint;
  v_period_start date;
  v_period_end date;
  v_approved_by uuid;
  v_approved_at timestamptz;
  v_released_by uuid;
  v_released_at timestamptz;
  v_line_count integer;
  v_valid_count integer;
  v_purchase_handoff_batch_id uuid;
  v_purchase_handoff_revision_id uuid;
  v_purchase_handoff_line_id uuid;
  v_purchase_handoff_line_revision_id uuid;
  v_purchase_demand_reference_id uuid;
  v_line record;
  v_line_ids jsonb := '[]'::jsonb;
  v_line_revision_ids jsonb := '[]'::jsonb;
  v_reference_ids jsonb := '[]'::jsonb;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05d_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;
  v_confirmed_need_batch_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id');
  if v_confirmed_need_batch_id is null or (select count(*) from pg_catalog.jsonb_object_keys(v_payload)) <> 1 then
    return atlas_core.pa_05b_command_error(request, 'VALIDATION_FAILED', 'Provide only a valid confirmed_need_batch_id.', 'PLANNING', v_command_name);
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'PLANNING', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select cnb.wholesale_order_id, cnb.batch_status, cnb.version,
         cnb.period_start, cnb.period_end, wo.customer_id, wo.delivery_location_id, wo.service_date
    into v_wholesale_order_id, v_batch_status, v_batch_version,
         v_period_start, v_period_end, v_customer_id, v_delivery_location_id, v_service_date
  from atlas_planning.confirmed_need_batches cnb
  join atlas_planning.wholesale_orders wo on wo.wholesale_order_id = cnb.wholesale_order_id
  where cnb.confirmed_need_batch_id = v_confirmed_need_batch_id;
  if not found then
    return atlas_core.pa_05b_command_error(request, 'VALIDATION_FAILED', 'The Confirmed Need batch could not be validated.', 'PLANNING', v_command_name);
  end if;

  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'purchase_handoff.release', 'PLANNING', v_command_name,
    v_customer_id, v_delivery_location_id, null
  );
  if v_error is not null then return v_error; end if;
  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'PLANNING', 'confirmed-need-batch:' || v_confirmed_need_batch_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1 from atlas_admin.customers c where c.customer_id = v_customer_id for key share;
  perform 1 from atlas_admin.delivery_locations dl where dl.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_admin.ingredients i where i.ingredient_id in (
    select cnlr.ingredient_id from atlas_planning.confirmed_need_lines cnl
    join atlas_planning.confirmed_need_line_revisions cnlr on cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id
    where cnl.confirmed_need_batch_id = v_confirmed_need_batch_id and cnlr.is_current
  ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u where u.unit_id in (
    select cnlr.unit_id from atlas_planning.confirmed_need_lines cnl
    join atlas_planning.confirmed_need_line_revisions cnlr on cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id
    where cnl.confirmed_need_batch_id = v_confirmed_need_batch_id and cnlr.is_current
  ) order by u.unit_id for key share;
  perform 1 from atlas_planning.wholesale_orders wo where wo.wholesale_order_id = v_wholesale_order_id for key share;
  perform 1 from atlas_planning.confirmed_need_batches cnb where cnb.confirmed_need_batch_id = v_confirmed_need_batch_id for update;
  perform 1 from atlas_planning.confirmed_need_lines cnl where cnl.confirmed_need_batch_id = v_confirmed_need_batch_id order by cnl.confirmed_need_line_id for key share;
  perform 1 from atlas_planning.confirmed_need_line_revisions cnlr where cnlr.confirmed_need_line_id in (
    select cnl.confirmed_need_line_id from atlas_planning.confirmed_need_lines cnl where cnl.confirmed_need_batch_id = v_confirmed_need_batch_id
  ) and cnlr.is_current order by cnlr.confirmed_need_line_revision_id for key share;
  perform 1 from atlas_planning.confirmed_need_approval_snapshots cns where cns.confirmed_need_batch_id = v_confirmed_need_batch_id for key share;
  perform 1 from atlas_planning.confirmed_need_snapshot_lines cnsl where cnsl.confirmed_need_approval_snapshot_id in (
    select cns.confirmed_need_approval_snapshot_id from atlas_planning.confirmed_need_approval_snapshots cns
    where cns.confirmed_need_batch_id = v_confirmed_need_batch_id
  ) order by cnsl.confirmed_need_snapshot_line_id for key share;

  select cnb.wholesale_order_id, cnb.batch_status, cnb.version, cnb.period_start, cnb.period_end,
         cnb.approved_by_actor_id, cnb.approved_at, cnb.released_by_actor_id, cnb.released_at,
         wo.customer_id, wo.delivery_location_id, wo.service_date
    into v_wholesale_order_id, v_batch_status, v_batch_version, v_period_start, v_period_end,
         v_approved_by, v_approved_at, v_released_by, v_released_at,
         v_customer_id, v_delivery_location_id, v_service_date
  from atlas_planning.confirmed_need_batches cnb
  join atlas_planning.wholesale_orders wo on wo.wholesale_order_id = cnb.wholesale_order_id
  where cnb.confirmed_need_batch_id = v_confirmed_need_batch_id;

  if v_batch_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION', 'The Confirmed Need batch changed. Refresh before release.',
      'PLANNING', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_confirmed_need_batch_id), v_batch_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_line_count from atlas_planning.confirmed_need_lines cnl
  where cnl.confirmed_need_batch_id = v_confirmed_need_batch_id;
  select count(*)::integer into v_valid_count
  from atlas_planning.confirmed_need_lines cnl
  join atlas_planning.confirmed_need_line_revisions cnlr on cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id
  join atlas_planning.confirmed_need_approval_snapshots cns on cns.confirmed_need_batch_id = cnl.confirmed_need_batch_id and cns.approved_version = v_batch_version
  join atlas_planning.confirmed_need_snapshot_lines cnsl on cnsl.confirmed_need_approval_snapshot_id = cns.confirmed_need_approval_snapshot_id and cnsl.confirmed_need_line_revision_id = cnlr.confirmed_need_line_revision_id
  join atlas_planning.wholesale_order_line_revisions wolr on wolr.wholesale_order_line_revision_id = cnlr.wholesale_order_line_revision_id
  join atlas_planning.wholesale_order_lines wol on wol.wholesale_order_line_id = cnl.wholesale_order_line_id
  where cnl.confirmed_need_batch_id = v_confirmed_need_batch_id
    and wol.wholesale_order_id = v_wholesale_order_id
    and wolr.wholesale_order_line_id = cnl.wholesale_order_line_id
    and wolr.is_current and wolr.revision_status = 'RELEASED'
    and cnlr.is_current and cnlr.revision_status = 'RELEASED'
    and cnlr.confirmed_quantity > 0
    and wolr.requested_quantity = cnlr.theoretical_quantity
    and cnlr.theoretical_quantity = cnlr.confirmed_quantity
    and cnlr.confirmed_quantity = cnsl.approved_quantity
    and cnsl.ingredient_id = cnlr.ingredient_id and cnsl.unit_id = cnlr.unit_id
    and wolr.ingredient_id = cnlr.ingredient_id and wolr.unit_id = cnlr.unit_id;

  if v_batch_status <> 'RELEASED_FOR_PURCHASE_HANDOFF'
     or v_approved_by is null or v_approved_at is null or v_released_by is null or v_released_at is null
     or v_period_start <> v_service_date or v_period_end <> v_service_date
     or v_line_count < 1 or v_valid_count <> v_line_count
     or not exists (
       select 1 from atlas_admin.customers c
       join atlas_admin.delivery_locations dl on dl.delivery_location_id = v_delivery_location_id
       where c.customer_id = v_customer_id and c.customer_type = 'WHOLESALE'
         and c.customer_status = 'ACTIVE' and dl.customer_id = c.customer_id
         and dl.location_status = 'ACTIVE'
     )
     or exists (
       select 1 from atlas_planning.confirmed_need_lines cnl
       join atlas_planning.confirmed_need_line_revisions cnlr
         on cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id and cnlr.is_current
       join atlas_admin.ingredients i on i.ingredient_id = cnlr.ingredient_id
       join atlas_admin.units u on u.unit_id = cnlr.unit_id
       where cnl.confirmed_need_batch_id = v_confirmed_need_batch_id
         and (i.ingredient_status <> 'ACTIVE' or u.unit_status <> 'ACTIVE')
     )
     or exists (select 1 from atlas_planning.purchase_handoff_batches phb where phb.confirmed_need_batch_id = v_confirmed_need_batch_id) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'Purchase Handoff release requires one complete released Confirmed Need snapshot with no prior handoff.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  insert into atlas_planning.purchase_handoff_batches (
    confirmed_need_batch_id, period_start, period_end, handoff_status, version, created_by_actor_id
  ) values (
    v_confirmed_need_batch_id, v_period_start, v_period_end,
    'RELEASED_TO_PROCUREMENT', 1, v_actor_id
  ) returning purchase_handoff_batch_id into v_purchase_handoff_batch_id;

  insert into atlas_planning.purchase_handoff_revisions (
    purchase_handoff_batch_id, revision_number, revision_kind, revision_status,
    is_current, released_by_actor_id, released_at, reason_note, command_id
  ) values (
    v_purchase_handoff_batch_id, 1, 'BASE', 'RELEASED_TO_PROCUREMENT',
    true, v_actor_id, pg_catalog.transaction_timestamp(), request ->> 'reason_note',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
  ) returning purchase_handoff_revision_id into v_purchase_handoff_revision_id;

  for v_line in
    select cnl.confirmed_need_line_id, cnlr.confirmed_need_line_revision_id,
           cnlr.wholesale_order_line_revision_id, cnlr.ingredient_id,
           cnlr.confirmed_quantity, cnlr.unit_id,
           cnsl.confirmed_need_snapshot_line_id, cnsl.approved_quantity
    from atlas_planning.confirmed_need_lines cnl
    join atlas_planning.confirmed_need_line_revisions cnlr on cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id and cnlr.is_current
    join atlas_planning.confirmed_need_approval_snapshots cns on cns.confirmed_need_batch_id = cnl.confirmed_need_batch_id and cns.approved_version = v_batch_version
    join atlas_planning.confirmed_need_snapshot_lines cnsl on cnsl.confirmed_need_approval_snapshot_id = cns.confirmed_need_approval_snapshot_id and cnsl.confirmed_need_line_revision_id = cnlr.confirmed_need_line_revision_id
    where cnl.confirmed_need_batch_id = v_confirmed_need_batch_id
    order by cnl.confirmed_need_line_id
  loop
    insert into atlas_planning.purchase_handoff_lines (
      purchase_handoff_batch_id, confirmed_need_line_id
    ) values (v_purchase_handoff_batch_id, v_line.confirmed_need_line_id)
    returning purchase_handoff_line_id into v_purchase_handoff_line_id;
    v_line_ids := v_line_ids || pg_catalog.jsonb_build_array(v_purchase_handoff_line_id);

    insert into atlas_planning.purchase_handoff_line_revisions (
      purchase_handoff_revision_id, purchase_handoff_line_id,
      confirmed_need_line_revision_id, ingredient_id, handoff_quantity,
      unit_id, service_date, delivery_location_id, command_id
    ) values (
      v_purchase_handoff_revision_id, v_purchase_handoff_line_id,
      v_line.confirmed_need_line_revision_id, v_line.ingredient_id,
      v_line.approved_quantity, v_line.unit_id, v_service_date,
      v_delivery_location_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
    ) returning purchase_handoff_line_revision_id into v_purchase_handoff_line_revision_id;
    v_line_revision_ids := v_line_revision_ids || pg_catalog.jsonb_build_array(v_purchase_handoff_line_revision_id);

    insert into atlas_planning.purchase_demand_references (
      purchase_handoff_line_revision_id, confirmed_need_snapshot_line_id,
      wholesale_order_line_revision_id, approved_quantity, unit_id
    ) values (
      v_purchase_handoff_line_revision_id, v_line.confirmed_need_snapshot_line_id,
      v_line.wholesale_order_line_revision_id, v_line.approved_quantity, v_line.unit_id
    ) returning purchase_demand_reference_id into v_purchase_demand_reference_id;
    v_reference_ids := v_reference_ids || pg_catalog.jsonb_build_array(v_purchase_demand_reference_id);
  end loop;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at, payload_summary
  ) values (
    'PurchaseHandoffReleased', 'PLANNING', 'PurchaseHandoff', v_purchase_handoff_batch_id, 1,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object('confirmed_need_batch_id', v_confirmed_need_batch_id, 'purchase_handoff_revision_id', v_purchase_handoff_revision_id, 'line_count', v_line_count)
  ) returning domain_event_id into v_domain_event_id;
  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version_after,
    command_receipt_id, command_id, correlation_id, actor_id, reason_code, reason_note,
    after_summary, source_interface, occurred_at
  ) values (
    'PurchaseHandoffReleased', 'PLANNING', 'PurchaseHandoff', v_purchase_handoff_batch_id, 1,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status', 'RELEASED_TO_PROCUREMENT', 'line_count', v_line_count),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id', 'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'purchase_handoff_batch_id', v_purchase_handoff_batch_id,
      'purchase_handoff_revision_id', v_purchase_handoff_revision_id,
      'purchase_handoff_line_ids', v_line_ids,
      'purchase_handoff_line_revision_ids', v_line_revision_ids,
      'purchase_demand_reference_ids', v_reference_ids
    ),
    'new_versions', pg_catalog.jsonb_build_object('purchase_handoff_version', 1),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Purchase Handoff released to Procurement.',
    'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(request, 'RETRYABLE_CONCURRENCY_FAILURE', 'The command could not acquire a safe transaction state. Retry the exact request.', 'PLANNING', v_command_name, true);
  when unique_violation then
    return atlas_core.pa_05b_command_error(request, 'INVARIANT_VIOLATION', 'A Purchase Handoff already exists for this Confirmed Need.', 'PLANNING', v_command_name);
  when others then
    return atlas_core.pa_05b_command_error(request, 'INTERNAL_COMMAND_FAILURE', 'The Purchase Handoff could not be released safely.', 'PLANNING', v_command_name);
end;
$$;

create or replace function atlas_api.release_dispatch_requirement(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'release_dispatch_requirement';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_purchase_handoff_revision_id uuid;
  v_purchase_handoff_batch_id uuid;
  v_confirmed_need_batch_id uuid;
  v_wholesale_order_id uuid;
  v_handoff_status text;
  v_handoff_version bigint;
  v_revision_status text;
  v_revision_current boolean;
  v_released_by uuid;
  v_released_at timestamptz;
  v_customer_id uuid;
  v_delivery_location_id uuid;
  v_service_date date;
  v_customer_name text;
  v_customer_status text;
  v_customer_type text;
  v_location_customer_id uuid;
  v_location_name text;
  v_address_text text;
  v_timezone_name text;
  v_location_status text;
  v_line_count integer;
  v_valid_count integer;
  v_scope_count integer;
  v_dispatch_requirement_id uuid;
  v_dispatch_requirement_revision_id uuid;
  v_dispatch_requirement_line_id uuid;
  v_dispatch_requirement_line_revision_id uuid;
  v_line record;
  v_line_ids jsonb := '[]'::jsonb;
  v_line_revision_ids jsonb := '[]'::jsonb;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_response jsonb;
begin
  v_error := atlas_core.pa_05d_validate_command_request(request, v_command_name);
  if v_error is not null then return v_error; end if;
  v_purchase_handoff_revision_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'purchase_handoff_revision_id');
  if v_purchase_handoff_revision_id is null or (select count(*) from pg_catalog.jsonb_object_keys(v_payload)) <> 1 then
    return atlas_core.pa_05b_command_error(request, 'VALIDATION_FAILED', 'Provide only a valid purchase_handoff_revision_id.', 'PLANNING', v_command_name);
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'PLANNING', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select phr.purchase_handoff_batch_id, phb.confirmed_need_batch_id,
         cnb.wholesale_order_id, phb.handoff_status, phb.version,
         phr.revision_status, phr.is_current, phr.released_by_actor_id, phr.released_at,
         wo.customer_id, wo.delivery_location_id, wo.service_date
    into v_purchase_handoff_batch_id, v_confirmed_need_batch_id,
         v_wholesale_order_id, v_handoff_status, v_handoff_version,
         v_revision_status, v_revision_current, v_released_by, v_released_at,
         v_customer_id, v_delivery_location_id, v_service_date
  from atlas_planning.purchase_handoff_revisions phr
  join atlas_planning.purchase_handoff_batches phb on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
  join atlas_planning.confirmed_need_batches cnb on cnb.confirmed_need_batch_id = phb.confirmed_need_batch_id
  join atlas_planning.wholesale_orders wo on wo.wholesale_order_id = cnb.wholesale_order_id
  where phr.purchase_handoff_revision_id = v_purchase_handoff_revision_id;
  if not found then
    return atlas_core.pa_05b_command_error(request, 'VALIDATION_FAILED', 'The Purchase Handoff revision could not be validated.', 'PLANNING', v_command_name);
  end if;

  v_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'dispatch_requirement.release', 'PLANNING', v_command_name,
    v_customer_id, v_delivery_location_id, null
  );
  if v_error is not null then return v_error; end if;
  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, v_command_name, 'PLANNING', 'purchase-handoff-revision:' || v_purchase_handoff_revision_id::text
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1 from atlas_admin.customers c where c.customer_id = v_customer_id for key share;
  perform 1 from atlas_admin.delivery_locations dl where dl.delivery_location_id = v_delivery_location_id for key share;
  perform 1 from atlas_admin.ingredients i where i.ingredient_id in (
    select phlr.ingredient_id from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_revision_id = v_purchase_handoff_revision_id
  ) order by i.ingredient_id for key share;
  perform 1 from atlas_admin.units u where u.unit_id in (
    select phlr.unit_id from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_revision_id = v_purchase_handoff_revision_id
  ) order by u.unit_id for key share;
  perform 1 from atlas_planning.wholesale_orders wo where wo.wholesale_order_id = v_wholesale_order_id for key share;
  perform 1 from atlas_planning.confirmed_need_batches cnb where cnb.confirmed_need_batch_id = v_confirmed_need_batch_id for key share;
  perform 1 from atlas_planning.purchase_handoff_batches phb where phb.purchase_handoff_batch_id = v_purchase_handoff_batch_id for update;
  perform 1 from atlas_planning.purchase_handoff_revisions phr where phr.purchase_handoff_revision_id = v_purchase_handoff_revision_id for key share;
  perform 1 from atlas_planning.purchase_handoff_lines phl where phl.purchase_handoff_batch_id = v_purchase_handoff_batch_id order by phl.purchase_handoff_line_id for key share;
  perform 1 from atlas_planning.purchase_handoff_line_revisions phlr where phlr.purchase_handoff_revision_id = v_purchase_handoff_revision_id order by phlr.purchase_handoff_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_demand_references pdr where pdr.purchase_handoff_line_revision_id in (
    select phlr.purchase_handoff_line_revision_id from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_revision_id = v_purchase_handoff_revision_id
  ) order by pdr.purchase_demand_reference_id for key share;

  select phb.handoff_status, phb.version, phr.revision_status, phr.is_current,
         phr.released_by_actor_id, phr.released_at,
         c.customer_name, c.customer_type, c.customer_status,
         dl.customer_id, dl.location_name, dl.address_text, dl.timezone_name, dl.location_status
    into v_handoff_status, v_handoff_version, v_revision_status, v_revision_current,
         v_released_by, v_released_at,
         v_customer_name, v_customer_type, v_customer_status,
         v_location_customer_id, v_location_name, v_address_text, v_timezone_name, v_location_status
  from atlas_planning.purchase_handoff_revisions phr
  join atlas_planning.purchase_handoff_batches phb on phb.purchase_handoff_batch_id = phr.purchase_handoff_batch_id
  join atlas_admin.customers c on c.customer_id = v_customer_id
  join atlas_admin.delivery_locations dl on dl.delivery_location_id = v_delivery_location_id
  where phr.purchase_handoff_revision_id = v_purchase_handoff_revision_id;

  if v_handoff_version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.pa_05b_command_error(
      request, 'STALE_VERSION', 'The Purchase Handoff changed. Refresh before releasing the requirement.',
      'PLANNING', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_purchase_handoff_batch_id), v_handoff_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_line_count
  from atlas_planning.purchase_handoff_lines phl where phl.purchase_handoff_batch_id = v_purchase_handoff_batch_id;
  select count(*)::integer into v_valid_count
  from atlas_planning.purchase_handoff_lines phl
  join atlas_planning.purchase_handoff_line_revisions phlr
    on phlr.purchase_handoff_line_id = phl.purchase_handoff_line_id
   and phlr.purchase_handoff_revision_id = v_purchase_handoff_revision_id
  join atlas_planning.confirmed_need_lines cnl
    on cnl.confirmed_need_line_id = phl.confirmed_need_line_id
   and cnl.confirmed_need_batch_id = v_confirmed_need_batch_id
  join atlas_planning.confirmed_need_line_revisions cnlr
    on cnlr.confirmed_need_line_revision_id = phlr.confirmed_need_line_revision_id
   and cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id
  join atlas_planning.confirmed_need_batches cnb
    on cnb.confirmed_need_batch_id = v_confirmed_need_batch_id
   and cnb.wholesale_order_id = v_wholesale_order_id
  join atlas_planning.purchase_demand_references pdr
    on pdr.purchase_handoff_line_revision_id = phlr.purchase_handoff_line_revision_id
  join atlas_planning.confirmed_need_approval_snapshots cns
    on cns.confirmed_need_batch_id = v_confirmed_need_batch_id
   and cns.approved_version = cnb.version
  join atlas_planning.confirmed_need_snapshot_lines cnsl
    on cnsl.confirmed_need_snapshot_line_id = pdr.confirmed_need_snapshot_line_id
   and cnsl.confirmed_need_approval_snapshot_id = cns.confirmed_need_approval_snapshot_id
   and cnsl.confirmed_need_line_revision_id = cnlr.confirmed_need_line_revision_id
  join atlas_planning.wholesale_order_line_revisions wolr
    on wolr.wholesale_order_line_revision_id = pdr.wholesale_order_line_revision_id
   and wolr.wholesale_order_line_revision_id = cnlr.wholesale_order_line_revision_id
  join atlas_planning.wholesale_order_lines wol
    on wol.wholesale_order_line_id = cnl.wholesale_order_line_id
   and wol.wholesale_order_line_id = wolr.wholesale_order_line_id
   and wol.wholesale_order_id = v_wholesale_order_id
  where phl.purchase_handoff_batch_id = v_purchase_handoff_batch_id
    and cnb.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
    and cnb.period_start = v_service_date and cnb.period_end = v_service_date
    and cnlr.is_current and cnlr.revision_status = 'RELEASED'
    and wolr.is_current and wolr.revision_status = 'RELEASED'
    and phlr.delivery_location_id = v_delivery_location_id
    and phlr.service_date = v_service_date
    and phlr.handoff_quantity > 0
    and phlr.ingredient_id = cnlr.ingredient_id
    and cnlr.ingredient_id = cnsl.ingredient_id
    and cnsl.ingredient_id = wolr.ingredient_id
    and phlr.unit_id = cnlr.unit_id
    and cnlr.unit_id = cnsl.unit_id
    and cnsl.unit_id = wolr.unit_id
    and wolr.unit_id = pdr.unit_id
    and wolr.requested_quantity = cnlr.theoretical_quantity
    and cnlr.theoretical_quantity = cnlr.confirmed_quantity
    and cnlr.confirmed_quantity = cnsl.approved_quantity
    and cnsl.approved_quantity = pdr.approved_quantity
    and pdr.approved_quantity = phlr.handoff_quantity;
  select count(*)::integer into v_scope_count from (
    select phlr.delivery_location_id, phlr.service_date
    from atlas_planning.purchase_handoff_line_revisions phlr
    where phlr.purchase_handoff_revision_id = v_purchase_handoff_revision_id
    group by phlr.delivery_location_id, phlr.service_date
  ) scopes;

  if v_handoff_status <> 'RELEASED_TO_PROCUREMENT'
     or v_revision_status <> 'RELEASED_TO_PROCUREMENT' or not v_revision_current
     or v_released_by is null or v_released_at is null
     or v_customer_type <> 'WHOLESALE' or v_customer_status <> 'ACTIVE'
     or v_location_status <> 'ACTIVE' or v_location_customer_id <> v_customer_id
     or v_line_count < 1 or v_valid_count <> v_line_count or v_scope_count <> 1
     or exists (
       select 1 from atlas_planning.purchase_handoff_line_revisions phlr
       where phlr.purchase_handoff_revision_id = v_purchase_handoff_revision_id
         and (phlr.delivery_location_id <> v_delivery_location_id or phlr.service_date <> v_service_date)
     )
     or exists (
       select 1 from atlas_planning.dispatch_requirement_revisions drr
       where drr.purchase_handoff_revision_id = v_purchase_handoff_revision_id
         and drr.is_current and drr.revision_status = 'RELEASED'
     ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'Dispatch Requirement release requires one current released handoff with complete single-scope lineage and active references.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  insert into atlas_planning.dispatch_requirements (
    source_of_need, customer_id, delivery_location_id, service_date,
    requirement_status, version
  ) values (
    'WHOLESALE', v_customer_id, v_delivery_location_id, v_service_date, 'RELEASED', 1
  ) returning dispatch_requirement_id into v_dispatch_requirement_id;

  insert into atlas_planning.dispatch_requirement_revisions (
    dispatch_requirement_id, purchase_handoff_revision_id, revision_number,
    revision_kind, revision_status, is_current, customer_name_snapshot,
    location_name_snapshot, address_snapshot, timezone_name,
    window_start_local, window_end_local, released_by_actor_id, released_at,
    reason_note, command_id
  ) values (
    v_dispatch_requirement_id, v_purchase_handoff_revision_id, 1,
    'BASE', 'RELEASED', true, v_customer_name, v_location_name, v_address_text,
    v_timezone_name, null, null, v_actor_id, pg_catalog.transaction_timestamp(),
    request ->> 'reason_note', atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
  ) returning dispatch_requirement_revision_id into v_dispatch_requirement_revision_id;

  for v_line in
    select phl.purchase_handoff_line_id, phlr.purchase_handoff_line_revision_id,
           phlr.ingredient_id, phlr.handoff_quantity, phlr.unit_id
    from atlas_planning.purchase_handoff_lines phl
    join atlas_planning.purchase_handoff_line_revisions phlr
      on phlr.purchase_handoff_line_id = phl.purchase_handoff_line_id
     and phlr.purchase_handoff_revision_id = v_purchase_handoff_revision_id
    where phl.purchase_handoff_batch_id = v_purchase_handoff_batch_id
    order by phl.purchase_handoff_line_id
  loop
    insert into atlas_planning.dispatch_requirement_lines (
      dispatch_requirement_id, purchase_handoff_line_id
    ) values (v_dispatch_requirement_id, v_line.purchase_handoff_line_id)
    returning dispatch_requirement_line_id into v_dispatch_requirement_line_id;
    v_line_ids := v_line_ids || pg_catalog.jsonb_build_array(v_dispatch_requirement_line_id);

    insert into atlas_planning.dispatch_requirement_line_revisions (
      dispatch_requirement_revision_id, dispatch_requirement_line_id,
      purchase_handoff_line_revision_id, ingredient_id, required_quantity, unit_id
    ) values (
      v_dispatch_requirement_revision_id, v_dispatch_requirement_line_id,
      v_line.purchase_handoff_line_revision_id, v_line.ingredient_id,
      v_line.handoff_quantity, v_line.unit_id
    ) returning dispatch_requirement_line_revision_id into v_dispatch_requirement_line_revision_id;
    v_line_revision_ids := v_line_revision_ids || pg_catalog.jsonb_build_array(v_dispatch_requirement_line_revision_id);
  end loop;

  insert into atlas_audit.domain_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version,
    command_receipt_id, command_id, correlation_id, actor_id, occurred_at, payload_summary
  ) values (
    'DispatchRequirementReleased', 'PLANNING', 'DispatchRequirement', v_dispatch_requirement_id, 1,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object('purchase_handoff_revision_id', v_purchase_handoff_revision_id, 'line_count', v_line_count)
  ) returning domain_event_id into v_domain_event_id;
  insert into atlas_audit.audit_events (
    event_type, source_domain, aggregate_type, aggregate_id, aggregate_version_after,
    command_receipt_id, command_id, correlation_id, actor_id, reason_code, reason_note,
    after_summary, source_interface, occurred_at
  ) values (
    'DispatchRequirementReleased', 'PLANNING', 'DispatchRequirement', v_dispatch_requirement_id, 1,
    v_receipt_id, atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'), v_actor_id,
    request ->> 'reason_code', request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status', 'RELEASED', 'line_count', v_line_count),
    'atlas_api', pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id', 'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'dispatch_requirement_id', v_dispatch_requirement_id,
      'dispatch_requirement_revision_id', v_dispatch_requirement_revision_id,
      'dispatch_requirement_line_ids', v_line_ids,
      'dispatch_requirement_line_revision_ids', v_line_revision_ids
    ),
    'new_versions', pg_catalog.jsonb_build_object('dispatch_requirement_version', 1),
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', 'Dispatch Requirement released.',
    'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(request, 'RETRYABLE_CONCURRENCY_FAILURE', 'The command could not acquire a safe transaction state. Retry the exact request.', 'PLANNING', v_command_name, true);
  when unique_violation then
    return atlas_core.pa_05b_command_error(request, 'INVARIANT_VIOLATION', 'A current released Dispatch Requirement already exists for this handoff.', 'PLANNING', v_command_name);
  when others then
    return atlas_core.pa_05b_command_error(request, 'INTERNAL_COMMAND_FAILURE', 'The Dispatch Requirement could not be released safely.', 'PLANNING', v_command_name);
end;
$$;

alter function atlas_core.pa_05d_safe_date(text) owner to atlas_owner;
alter function atlas_core.pa_05d_validate_command_request(jsonb, text) owner to atlas_owner;

grant atlas_planning_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_planning_command_runtime;
alter function atlas_api.record_wholesale_source(jsonb) owner to atlas_planning_command_runtime;
alter function atlas_api.release_wholesale_order(jsonb) owner to atlas_planning_command_runtime;
alter function atlas_api.release_purchase_handoff(jsonb) owner to atlas_planning_command_runtime;
alter function atlas_api.release_dispatch_requirement(jsonb) owner to atlas_planning_command_runtime;
revoke create on schema atlas_api from atlas_planning_command_runtime;

revoke execute on function atlas_core.pa_05d_safe_date(text),
  atlas_core.pa_05d_validate_command_request(jsonb, text)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.pa_05d_safe_date(text),
  atlas_core.pa_05d_validate_command_request(jsonb, text),
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_numeric(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(jsonb, uuid, text, text, text, uuid, uuid, uuid),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean)
to atlas_planning_command_runtime;

set role atlas_planning_command_runtime;
revoke execute on function
  atlas_api.record_wholesale_source(jsonb),
  atlas_api.release_wholesale_order(jsonb),
  atlas_api.release_purchase_handoff(jsonb),
  atlas_api.release_dispatch_requirement(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_api.record_wholesale_source(jsonb),
  atlas_api.release_wholesale_order(jsonb),
  atlas_api.release_purchase_handoff(jsonb),
  atlas_api.release_dispatch_requirement(jsonb)
to authenticated;

comment on function atlas_api.record_wholesale_source(jsonb)
  is 'PA-05D Planning command that records one Draft direct-wholesale source and stable lines.';
comment on function atlas_api.release_wholesale_order(jsonb)
  is 'PA-05D Planning command that releases a wholesale order and exact pass-through Confirmed Need snapshot.';
comment on function atlas_api.release_purchase_handoff(jsonb)
  is 'PA-05D Planning command that releases exact purchase demand without creating Procurement facts.';
comment on function atlas_api.release_dispatch_requirement(jsonb)
  is 'PA-05D Planning command that releases a wholesale delivery obligation without Dispatch execution facts.';
reset role;

revoke atlas_planning_command_runtime from postgres;
comment on role atlas_planning_command_runtime
  is 'PA-05D no-login, no-inherit SECURITY DEFINER owner for exactly four Planning commands.';
set role atlas_owner;
comment on schema atlas_api
  is 'Function-only Atlas Data API boundary with exactly 13 reviewed PA-05B, PA-05C, and PA-05D functions.';
reset role;
