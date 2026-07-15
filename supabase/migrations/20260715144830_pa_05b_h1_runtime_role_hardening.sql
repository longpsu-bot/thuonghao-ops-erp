-- PA-05B-H1 narrows the first command runtime by function family.  The
-- public atlas_api contract is unchanged: only authenticated can execute its
-- reviewed functions, while the SECURITY DEFINER owners receive the private
-- permissions required by their own command family.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'atlas_evidence_command_runtime') then
    create role atlas_evidence_command_runtime nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'atlas_dispatch_command_runtime') then
    create role atlas_dispatch_command_runtime nologin noinherit;
  end if;
end
$$;

-- The PA-05B shared command role is deliberately retired from the effective
-- runtime surface.  Existing policy rows are also removed so a later grant
-- cannot silently reactivate its old broad access.
revoke all on schema atlas_core, atlas_admin, atlas_planning, atlas_procurement,
  atlas_evidence, atlas_dispatch, atlas_audit, atlas_reporting, atlas_api
  from atlas_command_runtime;
revoke all on all tables in schema atlas_core, atlas_admin, atlas_planning,
  atlas_procurement, atlas_evidence, atlas_dispatch, atlas_audit, atlas_reporting
  from atlas_command_runtime;
revoke all on all sequences in schema atlas_core, atlas_admin, atlas_planning,
  atlas_procurement, atlas_evidence, atlas_dispatch, atlas_audit, atlas_reporting
  from atlas_command_runtime;
revoke execute on all functions in schema atlas_core, atlas_api from atlas_command_runtime;

do $$
declare
  policy_row record;
begin
  for policy_row in
    select n.nspname, c.relname, p.polname
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.polname like 'pa_05b_command_%'
  loop
    execute format('drop policy %I on %I.%I', policy_row.polname, policy_row.nspname, policy_row.relname);
  end loop;
end
$$;

-- Transfer only the reviewed PA-05B entry functions.  CREATE is temporary
-- and necessary for ownership reassignment; it is revoked before commit.
grant atlas_command_runtime, atlas_evidence_command_runtime, atlas_dispatch_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_evidence_command_runtime, atlas_dispatch_command_runtime;
alter function atlas_api.record_supplier_receiving_evidence(jsonb) owner to atlas_evidence_command_runtime;
alter function atlas_api.apply_supplier_evidence_to_allocation(jsonb) owner to atlas_evidence_command_runtime;
alter function atlas_api.confirm_dispatch_load(jsonb) owner to atlas_dispatch_command_runtime;
alter function atlas_api.record_dispatch_departure(jsonb) owner to atlas_dispatch_command_runtime;
alter function atlas_api.confirm_successful_delivery(jsonb) owner to atlas_dispatch_command_runtime;
revoke create on schema atlas_api from atlas_evidence_command_runtime, atlas_dispatch_command_runtime;
revoke atlas_command_runtime, atlas_evidence_command_runtime, atlas_dispatch_command_runtime from postgres;

-- Both command families need the same guarded actor, request, receipt, and
-- safe-error helpers.  They do not inherit one another's role privileges.
grant usage on schema atlas_core, atlas_admin, atlas_planning, atlas_procurement,
  atlas_evidence, atlas_audit, atlas_api to atlas_evidence_command_runtime;
grant usage on schema atlas_core, atlas_admin, atlas_planning, atlas_procurement,
  atlas_evidence, atlas_dispatch, atlas_audit, atlas_api to atlas_dispatch_command_runtime;

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
to atlas_evidence_command_runtime, atlas_dispatch_command_runtime;

grant select on atlas_core.actors, atlas_core.actor_auth_subjects, atlas_core.roles,
  atlas_core.capabilities, atlas_core.role_capabilities, atlas_core.actor_role_memberships,
  atlas_core.actor_scopes, atlas_core.command_receipts,
  atlas_admin.delivery_locations, atlas_admin.units, atlas_admin.ingredients, atlas_admin.suppliers,
  atlas_planning.dispatch_requirements, atlas_planning.dispatch_requirement_line_revisions,
  atlas_procurement.fulfilment_allocations, atlas_procurement.fulfilment_allocation_revisions,
  atlas_procurement.fulfilment_allocation_line_revisions, atlas_procurement.purchase_orders,
  atlas_procurement.purchase_order_revisions, atlas_procurement.purchase_order_line_revisions,
  atlas_evidence.supplier_receiving_evidence, atlas_evidence.evidence_applications
to atlas_evidence_command_runtime;
grant insert, update on atlas_core.command_receipts to atlas_evidence_command_runtime;
grant update on atlas_admin.delivery_locations, atlas_admin.units, atlas_admin.ingredients, atlas_admin.suppliers,
  atlas_planning.dispatch_requirements, atlas_planning.dispatch_requirement_line_revisions,
  atlas_procurement.fulfilment_allocations,
  atlas_procurement.fulfilment_allocation_revisions,
  atlas_procurement.fulfilment_allocation_line_revisions, atlas_procurement.purchase_orders,
  atlas_procurement.purchase_order_revisions, atlas_procurement.purchase_order_line_revisions,
  atlas_evidence.supplier_receiving_evidence, atlas_evidence.evidence_applications
to atlas_evidence_command_runtime;
grant insert on atlas_evidence.supplier_receiving_evidence, atlas_evidence.evidence_applications,
  atlas_audit.domain_events, atlas_audit.audit_events to atlas_evidence_command_runtime;
grant select (domain_event_id) on atlas_audit.domain_events to atlas_evidence_command_runtime;
grant select (audit_event_id) on atlas_audit.audit_events to atlas_evidence_command_runtime;

grant select on atlas_core.actors, atlas_core.actor_auth_subjects, atlas_core.roles,
  atlas_core.capabilities, atlas_core.role_capabilities, atlas_core.actor_role_memberships,
  atlas_core.actor_scopes, atlas_core.command_receipts,
  atlas_admin.delivery_locations, atlas_admin.units, atlas_admin.ingredients,
  atlas_planning.dispatch_requirements, atlas_planning.dispatch_requirement_revisions,
  atlas_planning.dispatch_requirement_line_revisions,
  atlas_procurement.fulfilment_allocations, atlas_procurement.fulfilment_allocation_revisions,
  atlas_procurement.fulfilment_allocation_line_revisions,
  atlas_evidence.supplier_receiving_evidence, atlas_evidence.evidence_applications,
  atlas_dispatch.dispatch_plans, atlas_dispatch.dispatch_plan_requirements,
  atlas_dispatch.dispatch_trips, atlas_dispatch.dispatch_stops, atlas_dispatch.dispatch_loads,
  atlas_dispatch.dispatch_load_lines, atlas_dispatch.dispatch_load_line_applications,
  atlas_dispatch.delivery_confirmations, atlas_dispatch.delivery_confirmation_lines
to atlas_dispatch_command_runtime;
grant insert, update on atlas_core.command_receipts to atlas_dispatch_command_runtime;
grant update on atlas_admin.delivery_locations, atlas_admin.units, atlas_admin.ingredients,
  atlas_planning.dispatch_requirements, atlas_planning.dispatch_requirement_revisions,
  atlas_planning.dispatch_requirement_line_revisions,
  atlas_procurement.fulfilment_allocations,
  atlas_procurement.fulfilment_allocation_revisions,
  atlas_procurement.fulfilment_allocation_line_revisions,
  atlas_evidence.supplier_receiving_evidence, atlas_evidence.evidence_applications,
  atlas_dispatch.dispatch_plans,
  atlas_dispatch.dispatch_trips, atlas_dispatch.dispatch_stops, atlas_dispatch.dispatch_loads,
  atlas_dispatch.dispatch_load_lines, atlas_dispatch.dispatch_load_line_applications,
  atlas_dispatch.delivery_confirmations
to atlas_dispatch_command_runtime;
grant insert on atlas_dispatch.dispatch_loads, atlas_dispatch.dispatch_load_lines,
  atlas_dispatch.dispatch_load_line_applications, atlas_dispatch.delivery_confirmations,
  atlas_dispatch.delivery_confirmation_lines, atlas_audit.domain_events, atlas_audit.audit_events
to atlas_dispatch_command_runtime;
grant select (delivery_confirmation_line_id) on atlas_dispatch.delivery_confirmation_lines to atlas_dispatch_command_runtime;
grant select (domain_event_id) on atlas_audit.domain_events to atlas_dispatch_command_runtime;
grant select (audit_event_id) on atlas_audit.audit_events to atlas_dispatch_command_runtime;

-- RLS exposure follows the same separation.  UPDATE grants on reference and
-- prerequisite rows are present only for PostgreSQL row locks; no policy
-- permits their mutation.
create policy pa_05b_h1_evidence_select on atlas_core.actors for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_core.actor_auth_subjects for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_core.roles for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_core.capabilities for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_core.role_capabilities for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_core.actor_role_memberships for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_core.actor_scopes for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_receipt_select on atlas_core.command_receipts for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_receipt_insert on atlas_core.command_receipts for insert to atlas_evidence_command_runtime with check (true);
create policy pa_05b_h1_evidence_receipt_update on atlas_core.command_receipts for update to atlas_evidence_command_runtime using (true) with check (true);

create policy pa_05b_h1_evidence_select on atlas_admin.delivery_locations for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_admin.units for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_admin.ingredients for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_admin.suppliers for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_planning.dispatch_requirements for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_planning.dispatch_requirement_line_revisions for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_procurement.fulfilment_allocations for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_procurement.fulfilment_allocation_revisions for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_procurement.fulfilment_allocation_line_revisions for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_procurement.purchase_orders for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_procurement.purchase_order_revisions for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_procurement.purchase_order_line_revisions for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_select on atlas_evidence.supplier_receiving_evidence for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_insert on atlas_evidence.supplier_receiving_evidence for insert to atlas_evidence_command_runtime with check (true);
create policy pa_05b_h1_evidence_select on atlas_evidence.evidence_applications for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_insert on atlas_evidence.evidence_applications for insert to atlas_evidence_command_runtime with check (true);
create policy pa_05b_h1_evidence_audit_insert on atlas_audit.domain_events for insert to atlas_evidence_command_runtime with check (true);
create policy pa_05b_h1_evidence_audit_insert on atlas_audit.audit_events for insert to atlas_evidence_command_runtime with check (true);
create policy pa_05b_h1_evidence_audit_select on atlas_audit.domain_events for select to atlas_evidence_command_runtime using (true);
create policy pa_05b_h1_evidence_audit_select on atlas_audit.audit_events for select to atlas_evidence_command_runtime using (true);

create policy pa_05b_h1_dispatch_select on atlas_core.actors for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_core.actor_auth_subjects for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_core.roles for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_core.capabilities for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_core.role_capabilities for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_core.actor_role_memberships for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_core.actor_scopes for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_receipt_select on atlas_core.command_receipts for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_receipt_insert on atlas_core.command_receipts for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05b_h1_dispatch_receipt_update on atlas_core.command_receipts for update to atlas_dispatch_command_runtime using (true) with check (true);

create policy pa_05b_h1_dispatch_select on atlas_admin.delivery_locations for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_admin.units for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_admin.ingredients for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_planning.dispatch_requirements for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_planning.dispatch_requirement_revisions for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_planning.dispatch_requirement_line_revisions for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_procurement.fulfilment_allocations for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_procurement.fulfilment_allocation_revisions for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_procurement.fulfilment_allocation_line_revisions for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_evidence.supplier_receiving_evidence for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_evidence.evidence_applications for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_dispatch.dispatch_plans for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_dispatch.dispatch_plan_requirements for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_select on atlas_dispatch.dispatch_trips for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_update on atlas_dispatch.dispatch_trips for update to atlas_dispatch_command_runtime using (true) with check (true);
create policy pa_05b_h1_dispatch_select on atlas_dispatch.dispatch_stops for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_update on atlas_dispatch.dispatch_stops for update to atlas_dispatch_command_runtime using (true) with check (true);
create policy pa_05b_h1_dispatch_select on atlas_dispatch.dispatch_loads for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_insert on atlas_dispatch.dispatch_loads for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05b_h1_dispatch_select on atlas_dispatch.dispatch_load_lines for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_insert on atlas_dispatch.dispatch_load_lines for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05b_h1_dispatch_select on atlas_dispatch.dispatch_load_line_applications for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_insert on atlas_dispatch.dispatch_load_line_applications for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05b_h1_dispatch_select on atlas_dispatch.delivery_confirmations for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_insert on atlas_dispatch.delivery_confirmations for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05b_h1_dispatch_select on atlas_dispatch.delivery_confirmation_lines for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_insert on atlas_dispatch.delivery_confirmation_lines for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05b_h1_dispatch_audit_insert on atlas_audit.domain_events for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05b_h1_dispatch_audit_insert on atlas_audit.audit_events for insert to atlas_dispatch_command_runtime with check (true);
create policy pa_05b_h1_dispatch_audit_select on atlas_audit.domain_events for select to atlas_dispatch_command_runtime using (true);
create policy pa_05b_h1_dispatch_audit_select on atlas_audit.audit_events for select to atlas_dispatch_command_runtime using (true);

comment on role atlas_evidence_command_runtime is 'PA-05B-H1 no-login SECURITY DEFINER owner for the two Evidence commands only.';
comment on role atlas_dispatch_command_runtime is 'PA-05B-H1 no-login SECURITY DEFINER owner for the three Dispatch commands only.';
