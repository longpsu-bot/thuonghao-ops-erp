do $pa_06c_fixture_assertion$
declare
  v_capability_count integer;
begin
  select count(*)::integer
  into v_capability_count
  from atlas_core.role_capabilities rc
  join atlas_core.capabilities c on c.capability_id = rc.capability_id
  where rc.role_id = 'b6c00000-0000-0000-0000-000000000001'
    and c.capability_code in (
      'dispatch_evidence_readiness.read',
      'operator_blockers.read',
      'command_audit_timeline.read',
      'supplier_receiving_evidence.record',
      'supplier_evidence_application.apply'
    )
    and c.capability_status = 'ACTIVE';

  if v_capability_count <> 5 then
    raise exception 'PA-06C exact five-capability role assertion failed.';
  end if;

  if not exists (
    select 1
    from atlas_core.actors a
    join atlas_core.actor_auth_subjects aas on aas.actor_id = a.actor_id
    join atlas_core.actor_role_memberships arm on arm.actor_id = a.actor_id
    where a.actor_id = 'b6000000-0000-0000-0000-000000000001'
      and a.actor_status = 'ACTIVE'
      and aas.auth_subject_id = 'b6000000-0000-0000-0000-000000000101'
      and aas.subject_status = 'ACTIVE'
      and arm.actor_role_membership_id = 'b6c00000-0000-0000-0000-000000000030'
      and arm.role_id = 'b6c00000-0000-0000-0000-000000000001'
      and arm.membership_status = 'ACTIVE'
  ) then
    raise exception 'PA-06C Auth subject, actor, and Evidence role assertion failed.';
  end if;

  if not exists (
    select 1
    from atlas_core.actor_scopes s
    where s.actor_scope_id = 'b6c00000-0000-0000-0000-000000000031'
      and s.actor_id = 'b6000000-0000-0000-0000-000000000001'
      and s.scope_kind = 'DELIVERY_LOCATION'
      and s.delivery_location_id = 'b6c10000-0000-0000-0000-000000000101'
      and s.scope_status = 'ACTIVE'
  ) then
    raise exception 'PA-06C delivery-location scope assertion failed.';
  end if;

  if not exists (
    select 1
    from atlas_planning.wholesale_order_line_revisions wolr
    join atlas_planning.confirmed_need_line_revisions cnlr
      on cnlr.wholesale_order_line_revision_id = wolr.wholesale_order_line_revision_id
    join atlas_planning.confirmed_need_snapshot_lines cnsl
      on cnsl.confirmed_need_line_revision_id = cnlr.confirmed_need_line_revision_id
    join atlas_planning.purchase_demand_references pdr
      on pdr.confirmed_need_snapshot_line_id = cnsl.confirmed_need_snapshot_line_id
     and pdr.wholesale_order_line_revision_id = wolr.wholesale_order_line_revision_id
    join atlas_planning.purchase_handoff_line_revisions phlr
      on phlr.purchase_handoff_line_revision_id = pdr.purchase_handoff_line_revision_id
    join atlas_planning.dispatch_requirement_line_revisions drlr
      on drlr.purchase_handoff_line_revision_id = phlr.purchase_handoff_line_revision_id
    join atlas_procurement.fulfilment_allocation_line_revisions falr
      on falr.dispatch_requirement_line_revision_id = drlr.dispatch_requirement_line_revision_id
    join atlas_procurement.fulfilment_allocation_revisions far
      on far.fulfilment_allocation_revision_id = falr.fulfilment_allocation_revision_id
    join atlas_procurement.fulfilment_allocations fa
      on fa.fulfilment_allocation_id = far.fulfilment_allocation_id
    join atlas_procurement.purchase_order_line_revisions polr
      on polr.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_revision_id = polr.purchase_order_revision_id
    join atlas_procurement.purchase_orders po
      on po.purchase_order_id = por.purchase_order_id
    where wolr.wholesale_order_line_revision_id = 'b6c20000-0000-0000-0000-000000000202'
      and wolr.revision_status = 'RELEASED'
      and wolr.requested_quantity = 10
      and cnlr.revision_status = 'RELEASED'
      and cnsl.approved_quantity = 10
      and pdr.approved_quantity = 10
      and phlr.handoff_quantity = 10
      and drlr.required_quantity = 10
      and fa.fulfilment_allocation_id = 'b6c30000-0000-0000-0000-000000000600'
      and fa.version = 1
      and fa.allocation_status = 'READY_FOR_DISPATCH'
      and far.is_current
      and falr.fulfilment_allocation_line_revision_id = 'b6c30000-0000-0000-0000-000000000603'
      and falr.allocated_quantity = 10
      and falr.line_status = 'READY_FOR_EVIDENCE'
      and po.purchase_order_id = 'b6c30000-0000-0000-0000-000000000700'
      and po.version = 1
      and po.purchase_order_status = 'RELEASED_TO_SUPPLIER'
      and por.is_current
      and polr.purchase_order_line_revision_id = 'b6c30000-0000-0000-0000-000000000703'
      and polr.ordered_quantity = 10
      and polr.unit_id = 'b6c10000-0000-0000-0000-000000000102'
      and polr.delivery_location_id = 'b6c10000-0000-0000-0000-000000000101'
      and polr.service_date = date '2026-07-18'
  ) then
    raise exception 'PA-06C deterministic supplier-direct lineage assertion failed.';
  end if;

  if exists (
    select 1
    from atlas_evidence.supplier_receiving_evidence sre
    where sre.purchase_order_line_revision_id = 'b6c30000-0000-0000-0000-000000000703'
  ) or exists (
    select 1
    from atlas_evidence.evidence_applications ea
    where ea.fulfilment_allocation_line_revision_id = 'b6c30000-0000-0000-0000-000000000603'
  ) then
    raise exception 'PA-06C fixture must begin without Evidence mutations.';
  end if;
end;
$pa_06c_fixture_assertion$;
